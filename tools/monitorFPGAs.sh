#!/bin/bash

#   Copyright 2023 rdugan
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

COLUMN_WIDTH=8
FIELDS=("id" "busid" "load" "memload" "vcc_int" "vcc_mem" "vcc_bram" "power" "fan" "temp" "mem_temp" "cclk" "mclk" "errs")
FIELD_LABELS=("id" "busid" "load" "memload" "vcc_int" "vcc_mem" "vcc_bram" "power" "fan" "temp" "mem_temp" "cclk" "mclk" "errs")
FIELD_SUFFIXES=("" "" "%" "%" "V" "V" "V" "W" "RPM" $'\xc2\xb0C' $'\xc2\xb0C' "MHz" "MHz" "%")

declare -A values
declare -A rowList
rows=0

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
print_row "${FIELD_LABELS[@]}"
echo -ne "\e[0m"

# iterate through sensors output, printing new row for each device
readarray -t devices <<< `jq -c '.DEVS[]' <<< "$(curl -s http://localhost:8081/devs)"`
for device in "${devices[@]}"
do
  if [ $((rows++)) -gt 0 ];
  then
    # print previous device row and reset values list
    rowList[${values[id]}]=$(print_device_status)
    unset values
  fi
  declare -A values

  # get sensor values
  readarray -t sensors <<< `jq -c '.ID, ."FPGA Activity", ."Core Voltage", ."Memory Voltage", ."BRAM Voltage", ."FPGA Power", ."Fan Speed", .Frequency, ."Memory Clock", .Temperature, ."Memory Temperature", ."Device Hardware%"' <<< "$device"`

  # get FPGA integer ID
  values[id]="${sensors[0]}"

  # locate pci bus ID and sysfs directory
  busID=""
  values[busid]="$busID"

  # get core load percent
  values[load]="${sensors[1]}"

  # get mem load percent
  values[memload]=""

  # get voltages
  printf -v values[vcc_int] "%01.03f" "${sensors[2]}"
  printf -v values[vcc_mem] "%01.03f" "${sensors[3]}"
  printf -v values[vcc_bram] "%01.03f" "${sensors[4]}"

  # get power
  printf -v values[power] "%.02f" "${sensors[5]}"

  # get fan speed
  values[fan]="${sensors[6]}"

  # get clocks
  values[cclk]="${sensors[7]}"
  values[mclk]="${sensors[8]}"

  # get temps
  printf -v values[temp] "%.01f" "${sensors[9]}"
  printf -v values[mem_temp] "%.01f" "${sensors[10]}"

  # get errs
  printf -v values[errs] "%01.03f" "${sensors[11]}"

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
