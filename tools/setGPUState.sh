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

if [ $# -lt 3 ];
then
  echo "Usage: $0 <GPU> <SCLK_STATE> <MCLK_STATE> [SOCCLK_STATE]"
  echo "Example: $0 1 7 3 7"
  exit 1;
fi

sysFSDir="/sys/class/drm/card${1}/device"

echo "manual" | tee ${sysFSDir}/power_dpm_force_performance_level > /dev/null 2>&1

if [ $# = 4 ];
then
  echo $4 | tee ${sysFSDir}/pp_dpm_socclk > /dev/null 2>&1
fi

echo $2 | tee ${sysFSDir}/pp_dpm_sclk > /dev/null 2>&1
echo $3 | tee ${sysFSDir}/pp_dpm_mclk > /dev/null 2>&1

sleep 1
./getGPUState.sh $1
