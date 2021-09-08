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

if [ $# != 2 ];
then
  echo "Usage: $0 <GPU_ID> <PPT_File>"
  exit 1;
fi

ppt="/sys/class/drm/card${1}/device/pp_table"
cat $2 |sponge $ppt

echo "Wrote ${2} to ${ppt}"
