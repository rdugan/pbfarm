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

if [ $# != 2 ] || \
   [[ ! $1 =~ ^([0-9]+(,[0-9]+)*|all)$ ]] || \
   [[ ! $2 =~ ^(mw29|mw31|cng|cnv2|cnh|cnt|ccx|eth|nim|kawpow|ergo)$ ]];
then
  echo "$0 <N[,N]>|all mw29|mw31|cng|cnv2|cnh|cnt|ccx|eth|nim|kawpow|ergo"
  exit 1
fi

cd $(dirname $0)

DEVICES="$1"
COIN=$2
ALGO=$COIN

CONFIG_FILE="../config/json/$ALGO.json"

numFPGAs=`find /sys/devices -type f -name "product" -print0 | xargs -0 -e grep "A-U55N" |wc -l`

if [[ $DEVICES =~ ^[0-9] ]]; then
  DEVICES=(${DEVICES//,/ })
else
  DEVICES=($(seq 0 1 $numFPGAs))
fi

config=`jq '.' $CONFIG_FILE`
if [[ -z $config ]]; then
  echo "Missing or malformed config file $(readlink -f $CONFIG_FILE)"
  exit 1
fi

defaultHashrate=`jq '.configDefaults.hashrateTarget' <<< "$config"`
defaultClocks=`jq '.configDefaults.clocks' <<< "$config"`
defaultVoltages=`jq '.configDefaults.voltages' <<< "$config"`

declare -a intVoltages bramVoltages memVoltages
for i in "${DEVICES[@]}"
do
  deviceConfig=`jq --argjson i "$i" '.devices[] | select(.id == $i)' <<< "$config"`

  HR_TARGET=`jq '.config? | .hashrateTarget' <<< "$deviceConfig"`
  [[ -z $HR_TARGET || $HR_TARGET = "null" ]] && HR_TARGET=$defaultHashrate
  HR_TARGET="${HR_TARGET//./$''}"

  readarray -t configValues <<< `jq '.id, .arch' <<< "$deviceConfig"`
  INSTANCE_ID=${configValues[0]}
  DEVICE_ARCH=${configValues[1]}

  # get device specific clocks
  deviceClocks=`jq '.config? | .clocks' <<< "$deviceConfig"`
  # merge default and device clocks
  clocks=`echo "$defaultClocks $deviceClocks" | jq -s add`
  # pull individual values into corresponding arrays
  readarray -t configValues <<< `jq '.fpga_clock_core, .fpga_clock_mem' <<< "$clocks"`
  coreClocks[$i]=${configValues[0]}
  memClocks[$i]=${configValues[1]}

  # get device specific voltages
  deviceVoltages=`jq '.config? | .voltages' <<< "$deviceConfig"`
  # merge default and device voltages
  voltages=`echo "$defaultVoltages $deviceVoltages" | jq -s add`
  # pull individual values into corresponding arrays
  readarray -t configValues <<< `jq '.fpga_vcc_int, .fpga_vcc_bram, .fpga_vcc_mem' <<< "$voltages"`
  intVoltages[$i]=${configValues[0]}
  bramVoltages[$i]=${configValues[1]}
  memVoltages[$i]=${configValues[2]}
done

join () {
  local IFS="$1"
  shift
  echo "$*"
}

# return (print) comma separate values
join , "${coreClocks[@]}"
join , "${memClocks[@]}"

join , "${intVoltages[@]}"
join , "${bramVoltages[@]}"
join , "${memVoltages[@]}"
