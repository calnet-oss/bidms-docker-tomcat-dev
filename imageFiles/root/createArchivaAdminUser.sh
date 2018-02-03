#!/bin/bash

#
# Copyright (c) 2017, Regents of the University of California and
# contributors.
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
# IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

USERNAME=$1

# Specifing password file is optional; if not specified, password will be
# read from stdin
PASSWORD_FILE=$2

if [ -z "$USERNAME" ]; then
  echo "Username is required as first argument" > /dev/stderr
  exit 1
fi

# Archiva passwords require at least one number
if [ ! -z "$PASSWORD_FILE" ]; then
  if [ ! -f "$PASSWORD_FILE" ]; then
    echo "$PASSWORD_FILE does not exist" > /dev/stderr
    exit 1
  fi
  PASSWORD=$(cat $PASSWORD_FILE)
else
  echo -n "Password: "
  PASSWORD=$(read -s line && echo $line)
fi

content="{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\",\"confirmPassword\":\"${PASSWORD}\",\"fullName\":\"the administrator\",\"email\":\"root@localhost.bogus\",\"validated\":true,\"assignedRoles\":[],\"modified\":true,\"rememberme\":false,\"logged\":false}"
content_size="${#content}"

curl -k -f --connect-timeout 900 \
  'https://localhost:8560/restServices/redbackServices/userService/createAdminUser' \
  -H 'Host: localhost:8560' \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'Accept-Language: en-US,en;q=0.5' \
  -H 'Content-Type: application/json' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'Referer: https://localhost:8560/' \
  -H "Content-Length: $content_size" \
  -d "$content"
curl_exit_code=$?

unset PASSWORD
unset content
unset content_size

echo ""
echo "Curl response: $curl_exit_code"

exit $curl_exit_code
