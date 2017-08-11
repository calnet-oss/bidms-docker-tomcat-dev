#!/bin/bash

set -x

function check_exit {
  error_code=$?
  if [ $error_code != 0 ]; then
    echo "ERROR: last command exited with an error code of $error_code"
    exit $error_code
  fi
}

if [ ! -f "$1" ]; then
  echo "$1 does not exist"
  exit 1
fi

grep "common.loader=" "$1" | \
       sed 's#"$#","/usr/local/tomcat/common-lib/classes","/usr/local/tomcat/common-lib/*.jar"#' \
       > /tmp/catalina.properties.replacement || check_exit

cat > /tmp/catalina.properties.replacement.sed << EOF
/common\.loader/ {
  r /tmp/catalina.properties.replacement
  d
}
EOF
check_exit

sed -f /tmp/catalina.properties.replacement.sed -i "$1" || check_exit
rm -f /tmp/catalina.properties.replacement /tmp/catalina.properties.replacement.sed
