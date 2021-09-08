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

if [ $# -lt 1 ];
then
  echo "Usage: $0 <GPU_ID>"
  echo "Example: $0 1"
  exit 1;
fi

cd $(dirname $0)

hwmon="/sys/class/hwmon/hwmon$1"
chown root.miners $hwmon/pwm1
chown root.miners $hwmon/pwm1_enable
chmod g+w $hwmon/pwm1
chmod g+w $hwmon/pwm1_enable

# stupid hack to enable readout of fans w/ manual pwm control
echo "1" | tee $hwmon/pwm1_enable > /dev/null 2>&1
echo "50" | tee $hwmon/pwm1 > /dev/null 2>&1
echo "0" | tee $hwmon/fan1_enable > /dev/null 2>&1
