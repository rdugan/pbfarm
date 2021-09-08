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

if [ $# != 1 ];
then
  echo "Usage: $0 <WIN_PPT_File>"
  exit 1;
fi

PPTHEXFILE="$1.hex.ppt"
PPTBINFILE="$1.bin.ppt"
cp $1 $PPTHEXFILE

perl -0777i -pe 's/^.*?://s;' -pe 's/,//g;' -pe 's/\\\W*//sg;' $PPTHEXFILE
xxd -r -p $PPTHEXFILE $PPTBINFILE

printf "\nCreated ppt binary $PPTBINFILE\n\n"
