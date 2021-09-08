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

BUS=(`lspci |grep VGA |grep "Advanced Micro Devices" |cut -d' ' -f1`)
declare -a DRM

for ((i=0; i<${#BUS[@]}; i++))
do
  device=`find /sys/devices/pci0000\:00/ -name 0000\:${BUS[i]}`
  card=`ls $device/drm |grep card`
  DRM[$i]="${card:4}"
  echo "${BUS[i]} ${DRM[i]}"
done
