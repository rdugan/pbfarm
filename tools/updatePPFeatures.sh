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

cd $(dirname $0)

if [[ $# -lt 2 || ! $1 =~ ^[0-9]+$ || ! $2 =~ ^[+-][0-9A-Z_]+$ ]];
then
  echo "Usage: $0 <GPU_ID> <+/-><PP_FEATURE>"
  echo "Example: $0 0 -ECC"
  echo "For list of available features, use '+_' for PP_FEATURE argument"
  exit;
fi

OPERATION_ENABLE="+"
OPERATION_DISABLE="-"
FORMAT_VEGA=0
FORMAT_NAVI=1

operation=${2:0:1}
feature=${2:1}
featuresFileName="/sys/class/drm/card$1/device/pp_features"

# make sure file exists
if [[ ! -f "$featuresFileName" ]]
then
  echo "pp_features sysfs file not found for card $1"
  exit
fi

# read in file and parse first line to determine file format and retrieve current mask
readarray -t featuresFile <<< "$(cat $featuresFileName)"
readarray -d ' ' -t currentMaskItem <<< ${featuresFile[0]}
currentMask=""
format=""
if [[ "${currentMaskItem[0]}" =~ "Current" ]]
then
  currentMask="${currentMaskItem[2]}"
  format=$FORMAT_VEGA
elif [[ "${currentMaskItem[0]}" =~ "features" ]]
then
  highMask="${currentMaskItem[2]}"
  lowMask="${currentMaskItem[4]}"
  currentMask="$(( (highMask << 32) + lowMask ))"
  format=$FORMAT_NAVI
else
  echo "Unrecognized pp_features file format"
  exit
fi

declare -a featuresList

# loop through features list from sysfs file, looking for requested feature
for (( i=2; i<${#featuresFile[@]}; i++ ))
do
  read -ra featureItem <<< "${featuresFile[$i]}"

  # 'shift' off line number for navi list
  [[ $format -eq $FORMAT_NAVI ]] && featureItem=("${featureItem[@]:1}")

  featureName=${featureItem[0]}
  if [[ "$featureName" == "$feature" ]]
  then
    # found matching feature in list, build new mask
    featureMask="${featureItem[1]}"
    if [[ $format -eq $FORMAT_NAVI ]]
    then
      # navi lists return bit position in decimal rather than mask
      [[ "$featureMask" == "(" ]] && featureMask="${featureItem[2]}"
      bitPosition=$(echo $featureMask |sed 's/(*\(.*\))/\1/g')
      featureMask="$(( 1 << bitPosition ))"
    fi
    newMask=$currentMask
    operationText="unchanged"
    if [[ "$operation" == "$OPERATION_ENABLE" ]]
    then
      newMask=$(( currentMask | featureMask ))
      operationText="enabled"
    else
      newMask=$(( currentMask & $(( ~featureMask )) ))
      operationText="disabled"
    fi

    # write new mask back to sysfs, and report change to user
    printf "0x%x" $newMask |tee "$featuresFileName" > /dev/null 2>&1
    printf "%s feature %s for GPU %d (0x%x -> 0x%x)\n" $feature $operationText $1 $currentMask $newMask
    exit
  else
    # build list of feature names to report back to user in case requested feature not found
    featuresList+=("$featureName")
  fi
done

# requested feature not found, print list
echo "Feature $feature not found"
echo "Available features include:"
printf "  %s\n" "${featuresList[@]}"
