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

if [[ $# -lt 1 ]];
then
  echo "Usage: $0 [FAN_PWM_LIST]"
  echo "Example: $0 75 75 75 75"
  echo "     or: $0 50"
  echo "     or: $0 +5 +5"
  exit 1;
fi

cd $(dirname $0)

newFans=($@)

declare -a enabledFans
readarray -t enabledFans <<< `./octo_cli -r |grep "RPM in percent" |grep -e "[0-9]\+$" |cut -d " " -f 3`

f=${enabledFans[*]}
fanList="${f// /|}"

readarray -t currentFans <<< `./octo_cli -r |grep "Current PWM" |grep -e "FAN No. [$fanList]" |cut -d " " -f 6`

for (( i=0; i<${#newFans[@]} && i<${#enabledFans[@]}; i++ ))
do
  [[ ${newFans[$i]} =~ ^[+|-] ]] && v=$(( ${currentFans[$i]} + ${newFans[$i]} )) || v=${newFans[$i]}
  if [[ $v -lt 0 ]]
  then
    v=0
  elif [[ $v -gt 255 ]]
  then
    v=255
  fi

  ./octo_cli -f "${enabledFans[$i]}" -v "$v"
done
