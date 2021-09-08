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

if [ $# -lt 1 ] || [[ ! $1 =~ ^([0-9]+)$ ]];
then
  echo "Usage: $0 <GPU_ID>"
  echo "Example: $0 1"
  exit 1;
fi

declare -A PPT_IDS=( [Polaris]="0:25" [Vega]="0:27" [Navi]="1:125" [VII]="2:124" )
declare -a uppResults
uppKeys=""

sysFSDev="/sys/class/drm/card${1}/device"
ppt="${sysFSDev}/pp_table"

readarray -t uppResults <<< `upp -p $ppt get /TableRevision /FormatID`
[[ ${uppResults[0]} =~ ^ERROR ]] && readarray -t uppResults <<< `upp -p $ppt get /table_revision /format_id`
tableVersion="${uppResults[0]}:${uppResults[1]}"

if [ "$tableVersion" = "${PPT_IDS[Navi]}" ]; then
  uppKeys="/smc_pptable/MaxVoltageSoc /smc_pptable/MaxVoltageGfx /smc_pptable/MemMvddVoltage/3 /smc_pptable/MemVddciVoltage/3"
elif [ "$tableVersion" = "${PPT_IDS[VII]}" ]; then
  uppKeys="/smcPPTable/MaxVoltageSoc /smcPPTable/MaxVoltageGfx"
fi
readarray -t uppResults <<< `upp -p $ppt get $uppKeys`

if [ "$tableVersion" = "${PPT_IDS[Navi]}" ] || [ "$tableVersion" = "${PPT_IDS[VII]}" ]; then
  printf "\nMax SOC Voltage:                  %smV\n" $(( ${uppResults[0]} / 4 ))
  printf "Max Core Voltage:                 %smV\n" $(( ${uppResults[1]} / 4 ))

  if [ "$tableVersion" = "${PPT_IDS[Navi]}" ]; then
    printf "Mem Voltage: (mvddc):             %smV\n" $(( ${uppResults[2]} / 4 ))
    printf "Mem Controller Voltage (mvddci):  %smV\n" $(( ${uppResults[3]} / 4 ))
  fi

  socclkHeader="SOCCLK:"
  sclkHeader="SCLK:"
  mclkHeader="MCLK:"

  readarray -t sclkList <<< "$(cat ${sysFSDev}/pp_dpm_sclk)"
  readarray -t mclkList <<< "$(cat ${sysFSDev}/pp_dpm_mclk)"

  socclkFile="${sysFSDev}/pp_dpm_socclk"
  if [ -f "$socclkFile" ];
  then
    readarray -t socclkList <<< "$(cat $socclkFile)"
    printf "\n$socclkHeader\n"
    for j in "${socclkList[@]}"
    do
      echo "$j"
    done
  fi

  printf "\n$sclkHeader\n"
  for j in "${sclkList[@]}"
  do
    echo "$j"
  done

  printf "\n$mclkHeader\n"
  for j in "${mclkList[@]}"
  do
    echo "$j"
  done

  echo
fi
