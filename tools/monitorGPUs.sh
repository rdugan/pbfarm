#!/bin/bash

#   Copyright 2021 rdugan
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

MONITOR_MEM_ERRS=false

COLUMN_WIDTH=8
FIELDS=("id" "busid" "gfxload" "memload" "vddgfx" "power1" "fan1" "edge" "junction" "mem" "cclk" "mclk" "socclk")
FIELD_SUFFIXES=("" "" "%" "%" "V" "W" "RPM" $'\xc2\xb0C' $'\xc2\xb0C' $'\xc2\xb0C' "MHz" "MHz" "MHz")

if [ $MONITOR_MEM_ERRS = true ]; then
  FIELDS+=("mrerrs" "mwerrs")
  FIELD_SUFFIXES=("" "")
fi

declare -A values
declare -A rowList
rows=0

isRoot=0
if [[ $(id -u) -ne 0 ]];
then
  echo -e "\e[1;36m\nShowing current pstate cclk setting"
  echo -e "Run with root priveleges to enable actual cclk display\e[0m"
else
  isRoot=1
fi

trim() {
  local var="$*"
  # remove leading whitespace characters
  var="${var#"${var%%[![:space:]]*}"}"
  # remove trailing whitespace characters
  var="${var%"${var##*[![:space:]]}"}"   
  printf '%s' "$var"
}

pad_string() {
  padding=""
  stringLength=${#1}
  if [ $stringLength -lt $2 ];
  then
    local padding=$( printf '%0.s ' $(seq 1 $(( $2-$stringLength ))) )
  fi
  printf '%s%s' "$padding" "$1"
}

print_row() {
  printf "||"

  # print first column (gpu id) with width 2
  printf " %s |" "$(pad_string $1 2)"
  shift

  for field in "$@"
  do
    local paddedField=$(pad_string "$field" $COLUMN_WIDTH)
    printf " %s |" "$paddedField"
  done

  printf "|\n"
}

print_device_status () {
  local deviceValues=()
  local numFields=${#FIELDS[@]}
  local i=0

  # create array of value + suffix strings
  while [ $i -lt $numFields ]
  do
    local value=${values[${FIELDS[$i]}]}
    local suffix=""

    # print '-' if no value
    [[ ${#value} -gt 0 ]] && suffix="${FIELD_SUFFIXES[$i]}"
    [[ ${#suffix} -gt 0 ]] && suffix=" $suffix";

    deviceValues+=("${value:--}$suffix")

    ((i++))
  done
  print_row "${deviceValues[@]}"
}

get_state_clock() {
  local record
  local tokens

  for record in "$@"
  do
    if [[ $record =~ (\*) ]];
    then
      tokens=($record)
      echo "${tokens[1]%???}"
      break
    fi
  done
}

# print table header
echo -e "\e[1;36m"
print_row "${FIELDS[@]}"
echo -ne "\e[0m"

# iterate through sensors output, printing new row for each device
readarray -t sensors <<< "$(sensors -u)"
sensorsLength=${#sensors[@]}
i=0
while [ $i -lt $sensorsLength ]
do
  case ${sensors[$i]} in 
    amdgpu*)
      if [ $((rows++)) -gt 0 ];
      then
        # print previous device row and reset values list
        rowList[${values[id]}]=$(print_device_status)
        unset values
        declare -A values
      fi

      # get device name (according to sensors)
      device="${sensors[$i]}"

      # locate pci bus ID and sysfs directory
      busID=${device:11:2}
      values[busid]="$busID"
      sysDir="/sys/bus/pci/devices/0000:$busID:00.0"

      # get core load percent
      values[gfxload]="$(cat $sysDir/gpu_busy_percent)"

      # get mem load percent
      values[memload]="$(cat $sysDir/mem_busy_percent 2>/dev/null)"

      # get GPU name/integer ID
      cardName="$(ls $sysDir/drm/ |grep -i card)"
      cardNumber="${cardName:4}"
      values[id]="$cardNumber"

      if [[ isRoot -eq 1 ]];
      then
        # read actual core clock
        debugDir="/sys/kernel/debug/dri/$cardNumber"
        readarray -t gpuInfo <<< "$(cat $debugDir/amdgpu_pm_info)"
        for j in "${gpuInfo[@]}"
        do
          if [[ $j =~ (\(SCLK\)) ]];
          then
            tokens=($j)
            values[cclk]="${tokens[0]}"
            break
          fi
        done
      else
        # no root priveleges - read current state core clock instead of actual
        readarray -t sclkList <<< "$(cat $sysDir/pp_dpm_sclk)"
        values[cclk]=$(get_state_clock "${sclkList[@]}")
      fi

      # read state list for mem
      readarray -t mclkList <<< "$(cat $sysDir/pp_dpm_mclk)"
      values[mclk]=$(get_state_clock "${mclkList[@]}")

      # read state list for soc
      socclkFile="$sysDir/pp_dpm_socclk"
      if [ -f "$socclkFile" ];
      then
        readarray -t socclkList <<< "$(cat $socclkFile)"
        values[socclk]=$(get_state_clock "${socclkList[@]}")
      fi

      # read mem errs
      if [[ isRoot -eq 1 ]] && [ $MONITOR_MEM_ERRS = true ];
      then
        readarray -t memErrs <<< "$(./amdgpu-edcprobe -q $cardNumber)"
        values[mrerrs]=${memErrs[0]};
        values[mwerrs]=${memErrs[1]};
      fi

    ;;
    vddgfx*|fan1*|edge*|junction*|mem*|power1*)
      fieldName=${sensors[$i]%?}
      fields=(${sensors[$((++i))]})
      value=${fields[1]}
      [ "$fieldName" != "vddgfx" ] && value=${value%????}
      values[$fieldName]="$value"
    ;;
  esac
  ((i++))
done

# print last line
((rows++))
rowList[${values[id]}]=$(print_device_status)

# output all rows
for (( i=0; i<$rows; i++ ))
do
  printf "%s\n" "${rowList[$i]}"
done
