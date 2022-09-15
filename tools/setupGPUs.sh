#!/bin/bash

#   Copyright 2022 rdugan
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

is_unum() { case $1 in '' | . | *[!0-9.]* | *.*.* ) return 1;; esac; }

if [ $# != 3 ] || \
   [[ ! $1 =~ ^([0-9]+(,[0-9]+)*|all)$ ]] || \
   [[ ! $2 =~ ^(mw29|mw31|cng|cnv2|cnh|cnt|ccx|eth|nim|kawpow|ergo)$ ]] || \
   ! is_unum "$3"
then
  echo "Usage:   $0 <N[,N]>|all mw29|mw31|cng|cnv2|cnh|cnt|ccx|eth|nim|kawpow|ergo <HR>"
  echo "Example: $0 0,1 eth 50"
  exit 1
fi

cd $(dirname $0)

DEVICES="$1"
COIN=$2
ALGO=$COIN
TARGET_HR=${3//./_}

CONFIG_FILE="../config/json/${ALGO}_${TARGET_HR}.json"
CONFIGMAP_DIR="../config/json/config_maps"
PPT_DIR="../config/ppts"

CONFIG_TYPE_CLOCKS="clocks"
CONFIG_TYPE_VOLTAGES="voltages"

declare -a DRM_IDS
declare -a ARCHS
declare -A STATES
declare -A TIMINGS
declare -A ATITOOL_SETTINGS
declare -A PPT_SETTINGS

declare -A configMap

# check that ppt clocks/voltages are in ascending order after update
fix_ppt_order() {
  deviceID=$1
  pptFile=$2
  pptPath=$3
  v=$4
  mapType=$5

  if [[ $pptPath =~ ^(.*\/)([0-9]+)$ ]]
  then
    # requested update is for a table entry, need to ensure proper order
    pathRoot=${BASH_REMATCH[1]}
    pathIndex=${BASH_REMATCH[2]}
    while [ "$pathIndex" -gt 0 ]
    do
      # generate path for previous table index
      pathIndex=$(( pathIndex - 1 ))
      pptPath="${pathRoot}${pathIndex}"

      # get previous table index value
      previousValue=`upp -p $pptFile get $pptPath`
      # check that value is valid (integer) and is >/= subsequent value
      if [ "${previousValue##*[!0-9]*}" ]
      then
        if [[ $mapType == $CONFIG_TYPE_CLOCKS && "$previousValue" -ge "$v" ]]
        then
          # previous index value needs to be adjusted to be less than current
          v=$(( v - 5 ))
          PPT_SETTINGS[$deviceID]+="${pptPath}=${v} "
        elif [[ $mapType == $CONFIG_TYPE_VOLTAGES && "$previousValue" -gt "$v" ]]
        then
          # previous index value needs to be adjusted to be equal to current
          PPT_SETTINGS[$deviceID]+="${pptPath}=${v} "
        else
          v=$previousValue
        fi
      else
        # TODO: Add more robust error handling - terminate setup and return error?
        echo "Error reading $mapType index from $pptFile."
      fi
    done
  elif [[ $pptPath =~ ^(.*\/)Max([^\/]+)$ ]]
  then
    # requested update is for a Max value, find corresponding min value
    pptPath="${BASH_REMATCH[1]}Min${BASH_REMATCH[2]}"
    minValue=`upp -p $pptFile get $pptPath`

    if [ "${minValue##*[!0-9]*}" ] && [ "$minValue" -gt "$v" ]
    then
      # min value is valid (integer) and is > max value, update to equal max value
      PPT_SETTINGS[$deviceID]+="${pptPath}=${v} "
    fi
  elif [[ $pptPath =~ ^(.*\/)Min([^\/]+)$ ]]
  then
    # requested update is for a Min value, find corresponding max value
    pptPath="${BASH_REMATCH[1]}Max${BASH_REMATCH[2]}"
    maxValue=`upp -p $pptFile get $pptPath`

    if [ "${maxValue##*[!0-9]*}" ] && [ "$maxValue" -lt "$v" ]
    then
      # max value is valid (integer) and is < min value, update to equal min value
      PPT_SETTINGS[$deviceID]+="${pptPath}=${v} "
    fi
  fi
}

# update ppt with values from config
set_ppt_value() {
  deviceID=$1
  config=$2
  pptFile=$3
  arch=$4
  mapType=$5
  k=$6

  # search for ppt path in config map
  mapKey="${arch}.${mapType}.${k}"
  pptPath=${configMap[$mapKey]}
  if [[ -z "$pptPath" ]]
  then
    echo "$mapType key '$k' not found in config map"
  else
    # found corresponding ppt path, get value from config
    v=`jq -r --arg k "$k" '.[$k]' <<< "$config"`
    if [[ -z $v || "$v" == "null" ]]
    then
      echo "$mapType key '$k' not found in ppt"
    else
      # path and value are valid, issue update
      if [[ $mapType =~ $CONFIG_TYPE_VOLTAGES ]]
      then
        # voltages are stored as mV*4, rounded up to nearest multiple of 25
        v=$(( v * 4 ))
        v=$(( 25 * (v % 25 ? (v / 25) + 1 : v / 25) ))
      fi
      PPT_SETTINGS[$deviceID]+="${pptPath}=${v} "
      if [[ $mapType =~ $CONFIG_TYPE_CLOCKS|$CONFIG_TYPE_VOLTAGES ]] 
      then
        # check that any related table ordering is still appropriate
        fix_ppt_order "$deviceID" "$pptFile" "$pptPath" "$v" "$mapType"
      fi
    fi
  fi
}

readarray -t DRM_IDS <<< `./PCI_DRM_map.sh |cut -d' ' -f2`

if [[ $DEVICES =~ ^[0-9] ]]; then
  DEVICES=(${DEVICES//,/ })
else
  DEVICES=($(seq 0 1 $(( ${#DRM_IDS[@]}-1 ))))
fi

config=`jq '.' $CONFIG_FILE`
if [[ -z $config ]]; then
  echo "Missing or malformed config file $(readlink -f $CONFIG_FILE)"
  exit 1
fi

echo "Reading global and default settings..."

defaultHashrate=`jq '.configDefaults.hashrateTarget' <<< "$config"`
defaultPPTFile=`jq '.configDefaults.pptFile' <<< "$config"`

defaultTimings=`jq '.configDefaults.timings' <<< "$config"`
defaultStates=`jq '.configDefaults.states' <<< "$config"`
defaultClocks=`jq '.configDefaults.clocks' <<< "$config"`
defaultVoltages=`jq '.configDefaults.voltages' <<< "$config"`

echo "Reading config map..."

# load config maps for all unique archs enumerated in device configs
readarray -t uniqueArchs <<< `jq -r '.devices[]|.arch' $CONFIG_FILE |sort -u`
for i in "${uniqueArchs[@]}"
do
  # strip and lowercase arch name
  arch="${i,,}"
  arch="${arch// /}"

  mapFile="${CONFIGMAP_DIR}/${arch}.json"
  map=`jq '.' $mapFile`
  if [[ -z $map ]]; then
    echo "Missing or malformed config map file $(readlink -f $mapFile)"
    exit 1
  fi

  # extract map of ppt clock paths
  clocksMap=`jq '.map | .clocks' <<< "$map"`
  for j in `jq -r '. | keys[]' <<< "$clocksMap"`
  do
    k="${arch}.clocks.${j}"
    v=`jq -r --arg j "$j" '.[$j]' <<< "$clocksMap"`
    configMap[$k]=$v
  done

  # extract map of ppt voltage paths
  voltagesMap=`jq '.map | .voltages' <<< "$map"`
  for j in `jq -r '. | keys[]' <<< "$voltagesMap"`
  do
    k="${arch}.voltages.${j}"
    v=`jq -r --arg j "$j" '.[$j]' <<< "$voltagesMap"`
    configMap[$k]=$v
  done
done

for i in "${DEVICES[@]}"
do
  echo "Reading settings for device $i..."

  deviceConfig=`jq --argjson i "$i" '.devices[] | select(.id == $i)' $CONFIG_FILE`

  HR_TARGET=`jq '.config? | .hashrateTarget' <<< "$deviceConfig"`
  [[ -z $HR_TARGET || $HR_TARGET = "null" ]] && HR_TARGET=$defaultHashrate
  HR_TARGET="${HR_TARGET//./_}"

  INSTANCE_ID=`jq '.id' <<< "$deviceConfig"`

  i2cID=`jq '.i2cID' <<< "$deviceConfig"`

  gpuArch=`jq -r '.arch' <<< "$deviceConfig"`
  ARCHS[$i]="$gpuArch"
  configMapKey="${gpuArch,,}"
  configMapKey="${configMapKey// /}"

  echo " * ppt filename"

  # get device specific ppt filename template if exists
  pptFile=`jq '.config? | .pptFile' <<< "$deviceConfig"`
  [[ -z $pptFile || $pptFile = "null" ]] && pptFile=$defaultPPTFile
  # get full filename by populating placeholders
  eval PPTS[$i]="$pptFile"
  pptFile="${PPT_DIR}/${PPTS[$i]}"

  echo " * clocks"

  # get device specific clocks
  deviceClocks=`jq '.config? | .clocks' <<< "$deviceConfig"`
  # merge default and device clocks
  clocks=`echo "$defaultClocks $deviceClocks" | jq -s add`
  if [[ ! -z $clocks && "$clocks" != "null" ]]; then
    # extract core, mem, soc and fabric clock values from object, and
    # write clocks to ppt file, referencing config map for ppt paths
    for k in `jq -r '. | keys[]' <<< "$clocks"`
    do
      set_ppt_value "$i" "$clocks" "$pptFile" "$configMapKey" "$CONFIG_TYPE_CLOCKS" "$k"
    done
  fi

  echo " * timings"

  # get device specific timings
  deviceTimings=`jq '.config? | .timings' <<< "$deviceConfig"`
  # merge default and device timings
  timings=`echo "$defaultTimings $deviceTimings" | jq -s add`
  # build timings string
  if [[ ! -z $timings && "$timings" != "null" ]]; then
    for k in `jq -r '. | keys[]' <<< "$timings"`
    do
      v=`jq --arg k "$k" -r '.[$k]' <<< "$timings"`
      TIMINGS[$i]+="--$k $v "
    done
  fi

  echo " * DPM states"

  # get device specific DPM states
  deviceStates=`jq '.config? | .states' <<< "$deviceConfig"`
  # merge default and device states
  states=`echo "$defaultStates $deviceStates" | jq -s add`
  if [[ ! -z $states && "$states" != "null" ]]; then
    # extract core, mem, and soc state values from object
    states=(`jq -r '.core, .mem, .soc' <<< "$states"`)
    # add states to device array, stripping soc if null
    STATES[$i]=${states[@]/null}
  fi

  echo " * voltages"

  # get device specific voltages
  deviceVoltages=`jq '.config? | .voltages' <<< "$deviceConfig"`
  # merge default and device voltages
  voltages=`echo "$defaultVoltages $deviceVoltages" | jq -s add`
  # build voltages string
  if [[ ! -z $voltages && "$voltages" != "null" ]]; then
    for k in `jq -r '. | keys[]' <<< "$voltages"`
    do
      if [[ $k =~ vddcr_hbm && $gpuArch =~ Vega\ 20 ]]; then
        # mvddc control doesn't work in atitool - need to use i2c instead
        mvddc_increment="0.00625"
        mvddc_index=`echo "obase=16; ($v-$mvddc_increment)/($mvddc_increment*2)" | bc`
        I2C_SETTINGS[$i]="$i2cID 0x32 0xe3 0x${mvddc_index}"
      elif [[ $k =~ vddcr_hbm && $gpuArch =~ Vega\ 10 ]]; then
        ATITOOL_SETTINGS[$i]+="-$k=$v "
      elif [[ $k =~ vddci_mem && $gpuArch =~ Vega\ [12]0 ]]; then
        ATITOOL_SETTINGS[$i]+="-$k=$v "
      else
        set_ppt_value "$i" "$voltages" "$pptFile" "$configMapKey" "$CONFIG_TYPE_VOLTAGES" "$k"
      fi
    done
  fi
done

# everything up to this point has only been reading configs and 
# creating maps of various settings

# ALL SETTINGS ARE APPLIED BELOW THIS POINT

echo "Applying device settings..."

# wake GPUs up before anything else
./wake_gpus.sh

# NOTE: amdmemtweak and atitool use contiguous instance IDs, all other tools
#       use DRM IDs, which may not be contiguous due to the presence of 
#       non-AMDGPU devices
for i in "${DEVICES[@]}"
do
  DRM_ID=${DRM_IDS[$i]}

  [[ "${ARCHS[$i]:-}" =~ (Vega 20|Navi 10) ]] && ./updatePPFeatures.sh $DRM_ID -UCLK_DPM
  [[ "${ARCHS[$i]:-}" =~ (Navi 22) ]] && ./updatePPFeatures.sh $DRM_ID -DPM_UCLK

  # modify and apply soft powerplay tables
  if [[ ! -z "${PPTS[$i]:-}" ]]
  then
    pptFile="${PPT_DIR}/${PPTS[$i]}"
    [[ ! -z "${PPT_SETTINGS[$i]:-}" ]] && upp -p $pptFile set ${PPT_SETTINGS[$i]} --write
    ./setPPT.sh $DRM_ID "$pptFile"
  fi

  # set powerplay states and mem timings
  [[ ! -z "${STATES[$i]:-}" ]] && ./setGPUState.sh $DRM_ID ${STATES[$i]}
  [[ ! -z "${TIMINGS[$i]:-}" ]] && ./amdmemtweak --i $i ${TIMINGS[$i]}

  # non-standard voltage settings
  [[ ! -z "${I2C_SETTINGS[$i]:-}" ]] && i2cset -y -r ${I2C_SETTINGS[$i]}
  [[ ! -z "${ATITOOL_SETTINGS[$i]:-}" ]] && ./atitool -i=$i ${ATITOOL_SETTINGS[$i]}

  ./initFans.sh $DRM_ID 1

#  ./updatePPFeatures.sh $DRM_ID -ECC
#  ./updatePPFeatures.sh $DRM_ID +LINK_DPM
#  ./updatePPFeatures.sh $DRM_ID +FAN_CONTROL

   printf "\n"
done
