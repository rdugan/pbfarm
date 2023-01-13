#!/bin/bash

# TODO: Move these to config file
EXEC_DIR="/var/lib/pdu_watchdog"
STATUS_LOG_FILE="$EXEC_DIR/status.log"
CREDENTIALS_FILE="$EXEC_DIR/credentials"
REMOTE_DIR="$HOME/google-drive/pdu_watchdog"
REMOTE_FILE="${REMOTE_DIR}/selections"
REMOTE_STATUS_LOG_FILE="${REMOTE_DIR}/status.log"

declare -A SERVERS=(["PDU20_1"]="http://192.168.1.8" ["PDU30_1"]="http://192.168.1.9" ["PDU30_2"]="http://192.168.1.10")
declare -A RIG_OUTLETS=(["Octo8.1"]="PDU30_2.13" ["Octo8.2"]="PDU20_1.4" ["Octo8.3"]="PDU20_1.8" ["Octo8.4"]="PDU20_1.7" ["Octo12.1"]="PDU30_2.9" ["Octo12.2"]="PDU30_2.1" ["Octo12.3"]="PDU30_2.2" ["Octo12.4"]="PDU30_1.8" ["Octo12.5"]="PDU30_1.15")
declare -A OUTLET_ACTIONS=(["on"]=1 ["off"]=2 ["reboot"]=3)
METERED="PDU30_1 PDU30_2"

USERAGENT="User-Agent: Mozilla/5.0"
COOKIEJAR="$EXEC_DIR/pdu_cookies.txt"

declare -a selections
if [ $# -ge 1 ]; then
  selections=($@)
  mode="local"
else
  readarray -t selections < $REMOTE_FILE
  mode="remote"
fi

cd $(dirname $0)

readarray -t credentials < $CREDENTIALS_FILE
USERNAME="${credentials[0]}"
PASSWORD="${credentials[1]}"

declare -a STATUS
for s in "${selections[@]}"
do
  if [[ ! $s =~ ^(Octo[0-9]+\.[0-9]+)=(on|off|reboot)$ ]]; then
    STATUS+=("ERROR: Invalid argument '${s}'. Usage: $0 <rig_name>=<on|off|reset>")
    break
  fi

  rig=${BASH_REMATCH[1]}
  action=${BASH_REMATCH[2]}

  location=${RIG_OUTLETS["$rig"]}
  if [[ ! $location =~ ^(PDU.*?)\.([0-9]+)$ ]]; then
    STATUS+=("ERROR: Unknown rig: ${rig}")
    break
  fi

  outletAction=${OUTLET_ACTIONS["$action"]}
  if [[ -z $outletAction ]]; then
    STATUS+=("ERROR: Unknown action '$action' for rig ${rig}")
    break
  fi

  pdu=${BASH_REMATCH[1]}
  outlet=${BASH_REMATCH[2]}

  status="INFO: Commencing action '$action' for $pdu, outlet $outlet (${rig})... "
  loginReferer="${SERVERS[$pdu]}/login.html"
  if [[ $METERED =~ $pdu ]]; then
    # login
    curl -s -o /dev/null -L -c $COOKIEJAR -H "Referer: $loginReferer" -d username="$USERNAME" -d password="$PASSWORD" "${SERVERS[$pdu]}/login_pass.cgi"
    loginReferer="${SERVERS[$pdu]}/login_pass.html"
    for i in {0..2}; do
      [[ $i = 2 ]] && sleep 2
      curl -s -o /dev/null -b $COOKIEJAR -H "Referer: $loginReferer" "${SERVERS[$pdu]}/login_counter.html?stap=$i"
    done
    location=`curl -s -o /dev/null -w "%{redirect_url}" -b $COOKIEJAR -H "Referer: $loginReferer" "${SERVERS[$pdu]}/login.cgi?action=LOGIN"`
  else
    # login
    curl -s -o /dev/null -c $COOKIEJAR "${SERVERS[$pdu]}/login.html"
    location=`curl -s -o /dev/null -w "%{redirect_url}" -c $COOKIEJAR -b $COOKIEJAR -H "Referer: $loginReferer" --data-urlencode "username=${USERNAME}" --data-urlencode "password=${PASSWORD}" "${SERVERS[$pdu]}/login.cgi"`
  fi

  # select outlet(s)
  if ! [[ $location =~ "error" ]]; then
    location=`curl -s -o /dev/null -b $COOKIEJAR -H "Referer: $loginReferer" "${SERVERS[$pdu]}/outlet_confirm.cgi?ActionSel=${outletAction}&ActOut${outlet}=yes&action=Next+%C2%BB"`

    if ! [[ $location =~ "error" ]]; then
      curl -s -o /dev/null -b $COOKIEJAR -H "Referer: ${SERVERS[$pdu]}/outlet_confirm.html" "${SERVERS[$pdu]}/outlet.cgi?action=Apply"
      status+="done."
    fi

    # logout
    curl -s -o /dev/null -b $COOKIEJAR -H "Referer: ${SERVERS[$pdu]}/outlet.html" "${SERVERS[$pdu]}/logout.html"
  fi

  STATUS+=("$status")
done

# write action out to status log file
for s in "${STATUS[@]}"; do
  s="$(date) ${s}"
  echo "$s" >> $STATUS_LOG_FILE
  [[ "$mode" == "remote" ]] && echo "$s" >> $REMOTE_STATUS_LOG_FILE
done
