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

if [ $# -lt 1 ];
then
  echo "Usage: $0 <GPU> [DURATION]"
  echo "Example: $0 1 5"
  exit 1;
fi

duration=3
if [ $# = 2 ]; 
then 
  duration=$2
fi

hwmon="/sys/class/hwmon/hwmon$1"
echo "0" > $hwmon/pwm1_enable
sleep $duration
echo "2" > $hwmon/pwm1_enable;
