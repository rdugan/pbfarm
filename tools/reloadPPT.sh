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

if [ $# -lt 1 ] || \
   [[ ! $1 =~ ^([0-9][0-9]*)$ ]];
then
  echo "Usage: $0 <GPU_DRM_ID> [PPT_FILE]"
  echo "Example: $0 0"
  exit 1;
fi

GPU="$1"
PPT="$2"

sysfs="/sys/class/drm/card${GPU}/device"

# save dpm states
sclk=`cat ${sysfs}/pp_dpm_sclk |grep '*' |cut -d':' -f1`
mclk=`cat ${sysfs}/pp_dpm_mclk |grep '*' |cut -d':' -f1`
socclk=`cat ${sysfs}/pp_dpm_socclk |grep '*' |cut -d':' -f1`

# save fan state
hwmon=`find ${sysfs}/hwmon/ -mindepth 1 -type d -name 'hwmon*'`
pwmMode=`cat ${hwmon}/pwm1_enable`
pwmValue=`cat ${hwmon}/pwm1`

# write ppt over itself
[[ -z $PPT || ! -f $PPT ]] && PPT="${sysfs}/pp_table"
./setPPT.sh $GPU $PPT

# reload dpm states
./setGPUState.sh $GPU $sclk $mclk $socclk

# reload fan states
echo "$pwmMode" > ${hwmon}/pwm1_enable
[ $pwmMode -eq 1 ] && echo "$pwmValue" > ${hwmon}/pwm1
