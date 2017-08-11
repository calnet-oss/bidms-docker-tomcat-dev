#!/bin/bash

CONTAINER_DIR="/usr/local/archiva"
INSPECT=$(docker inspect bidms-tomcat-dev | sed -e '/Source/,/Destination/!d')

while read -ra arr; do
  if [ "${arr[0]}" == '"Source":' ]; then
    src=${arr[1]}
  elif [[ "${arr[0]}" == '"Destination":' && "${arr[1]}" == "\"$CONTAINER_DIR\"," ]]; then
    archiva_src=$src
  fi
done  <<< "$INSPECT"
archiva_src=$(echo $archiva_src|cut -d'"' -f2)

echo $archiva_src
