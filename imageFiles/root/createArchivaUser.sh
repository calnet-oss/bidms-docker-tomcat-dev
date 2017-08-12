#!/bin/sh

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

# Arg 1: login cookie
COOKIE=$1
# Arg 2: X-XSRF-TOKEN
XSRF_TOKEN=$2
# Arg 3: username
USERNAME=$3
# Arg 4: full name
FULLNAME=$4
# Arg 5: email
EMAIL=$5

# Arg 6: Specifing password file is optional; if not specified, password
# will be read from stdin
PASSWORD_FILE=$6

if [ -z "$COOKIE" ]; then
  echo "Login cookie is required as first argument" > /dev/stderr
  exit 1
fi
if [ -z "$XSRF_TOKEN" ]; then
  echo "XSRF token is required as second argument" > /dev/stderr
  exit 1
fi
if [ -z "$USERNAME" ]; then
  echo "Username is required as third argument" > /dev/stderr
  exit 1
fi
if [ -z "$FULLNAME" ]; then
  echo "Full name is required as fifth argument" > /dev/stderr
  exit 1
fi
if [ -z "$EMAIL" ]; then
  echo "Email address is required as sixth argument" > /dev/stderr
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

curl -k -v -f \
  'https://localhost:8560/restServices/redbackServices/userService/createUser' \
  -H 'Host: localhost:8560' \
  -H 'Accept: application/json, text/javascript, */*; q=0.01' \
  -H 'Accept-Language: en-US,en;q=0.5' \
  -H 'Content-Type: application/json' \
  -H 'X-Requested-With: XMLHttpRequest' \
  -H 'Referer: https://localhost:8560/' \
  -H "Cookie: $COOKIE" \
  -H "X-XSRF-TOKEN: $XSRF_TOKEN" \
  -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\",\"confirmPassword\":\"${PASSWORD}\",\"fullName\":\"${FULLNAME}\",\"email\":\"${EMAIL}\",\"validated\":true,\"assignedRoles\":[],\"modified\":true,\"rememberme\":false,\"logged\":false}"
curl_exit_code=$?
if [ $curl_exit_code != 0 ]; then
  echo "Add user failed" > /dev/stderr
  exit $curl_exit_code
fi
echo ""
