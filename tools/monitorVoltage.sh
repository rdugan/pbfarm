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

declare -a voltages
output=""

while true; do 
  D=`date "+%Y%m%d %H%M%S.%N"`
  previousOutput=$output
  output=""
  for i in {0..7}; do
    v=`cat /sys/class/drm/card$i/device/hwmon/hwmon$i/in0_input`
    if [ $v == ${voltages[i]} ]; then
      output+=" $v"
    else
      output+=" \e[1;31m$v\e[0m"
    fi
    voltages[$i]=$v
  done
  if [ "$output" != "$previousOutput" ]; then
    echo -e "$D ->$output"
  fi
done

