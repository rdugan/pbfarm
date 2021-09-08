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
   [[ ! $1 =~ ^([0-9](,[0-9])*|all)$ ]];
then
  echo "Usage: $0 <N[,N]>|all [delay]"
  echo "Example: $0 0 10"
  exit 1;
fi

declare -a GPUS

if [ $# = 2 ];
then
  sleep $2 
fi

if [ $1 = 'all' ];
then
  readarray -t devices <<< "$(./PCI_DRM_map.sh)"
  for r in "${devices[@]}"
  do
    items=(${r// / })
    GPUS+=(${items[1]})
  done
elif [[ $1 =~ ^[0-9] ]]; then
  GPUS=(${1//,/ })
fi

for i in "${GPUS[@]}"
do
  sysfs="/sys/class/drm/card${i}/device"

  # save dpm states
  sclk=`cat ${sysfs}/pp_dpm_sclk |grep '*' |cut -d':' -f1`
  mclk=`cat ${sysfs}/pp_dpm_mclk |grep '*' |cut -d':' -f1`
  socclk=`cat ${sysfs}/pp_dpm_socclk |grep '*' |cut -d':' -f1`

  # save fan state
  hwmon="/sys/class/hwmon/hwmon${i}"
  pwmMode=`cat ${hwmon}/pwm1_enable`
  pwmValue=`cat ${hwmon}/pwm1`

  # write ppt over itself
  ./setPPT.sh $i ${sysfs}/pp_table

  # reload dpm states
  ./setGPUState.sh $i $sclk $mclk $socclk

  # reload fan states
  echo "$pwmMode" > ${hwmon}/pwm1_enable
  [ $pwmMode -eq 1 ] && echo "$pwmValue" > ${hwmon}/pwm1
done
