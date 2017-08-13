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

function check_exit {
  error_code=$?
  if [ $error_code != 0 ]; then
    echo "ERROR: last command exited with an error code of $error_code"
    exit $error_code
  fi
}

if [ -f config.env ]; then
  . ./config.env || check_exit
else
  cat << EOF
Warning: There is no config.env file.  It is recommended you copy
config.env.template to config.env and edit it before running this, otherwise
the argument defaults in the Dockerfile will be used.
EOF
fi

if [ ! -f imageFiles/tmp_tomcat/tomcat.jks ]; then
  echo "imageFiles/tmp_tomcat/tomcat.jks is missing.  Run ./generateTLSCert.sh"
  exit 1
fi
if [ ! -f imageFiles/tmp_tomcat/tomcat_pubkey.pem ]; then
  echo "imageFiles/tmp_tomcat/tomcat_pubkey.pem is missing.  Run ./generateTLSCert.sh"
  exit 1
fi

if [ ! -z "$APT_PROXY_URL" ]; then
  ARGS+="--build-arg APT_PROXY_URL=$APT_PROXY_URL "
elif [ -e $HOME/.aptproxy ]; then
  apt_proxy_url=$(cat $HOME/.aptproxy)
  ARGS+="--build-arg APT_PROXY_URL=$apt_proxy_url "
fi

echo "Using ARGS: $ARGS"
docker build $ARGS -t bidms/tomcat-dev:latest imageFiles || check_exit

#
# We want to temporarily start up the image so we can copy the contents of
# /var/lib/tomcat8 and /usr/local/archiva to the host.  On subsequent
# container runs, we will mount these host directories into the container. 
# i.e., we want to persist data files across container runs.
#
if [[ ! -e "$HOST_TOMCAT_DIRECTORY" || ! -e "$HOST_ARCHIVA_DIRECTORY" ]]; then
  echo "Temporarily starting the container to copy directories to host"
  NO_INTERACTIVE="true" \
  NO_HOST_TOMCAT_DIRECTORY="true" \
  NO_HOST_ARCHIVA_DIRECTORY="true" \
  ./runContainer.sh || check_exit
  startedContainer="true"
fi

# Tomcat host directory
if [ ! -e "$HOST_TOMCAT_DIRECTORY" ]; then
  TMP_TOMCAT_HOST_DIR=$(./getTomcatHostDir.sh)
  if [[ $? != 0 || -z "$TMP_TOMCAT_HOST_DIR" ]]; then
    echo "./getTomcatHostDir.sh failed"
    echo "Stopping the container."
    ./stopContainer.sh
    exit 1
  fi

  echo "Temporary host Tomcat directory: $TMP_TOMCAT_HOST_DIR"
  echo "$HOST_TOMCAT_DIRECTORY does not yet exist.  Copying from temporary location."
  echo "You must have sudo access for this to work and you may be prompted for a sudo password."
  sudo cp -pr $TMP_TOMCAT_HOST_DIR $HOST_TOMCAT_DIRECTORY
  if [ $? != 0 ]; then
    echo "copy from $TMP_TOMCAT_HOST_DIR to $HOST_TOMCAT_DIRECTORY failed"
    echo "Stopping the container."
    ./stopContainer.sh
    exit 1
  fi
  echo "Successfully copied to $HOST_TOMCAT_DIRECTORY"
else
  echo "$HOST_TOMCAT_DIRECTORY on the host already exists.  Not copying anything."
  echo "If you want a clean install, delete $HOST_TOMCAT_DIRECTORY and re-run this script."
fi

# Archiva host directory
if [ ! -e "$HOST_ARCHIVA_DIRECTORY" ]; then
  TMP_ARCHIVA_HOST_DIR=$(./getArchivaHostDir.sh)
  if [[ $? != 0 || -z "$TMP_ARCHIVA_HOST_DIR" ]]; then
    echo "./getArchivaHostDir.sh failed"
    echo "Stopping the container."
    ./stopContainer.sh
    exit 1
  fi

  echo "Temporary host Archiva directory: $TMP_ARCHIVA_HOST_DIR"
  
  # Initialize Archiva by hitting some URLs.
  echo "Initializing Archiva.  This will take a few seconds as we need to wait for Tomcat to start."
  sleep 15
  docker cp imageFiles/tmp_passwords/archiva_admin_pw bidms-tomcat-dev:/tmp
  if [ $? != 0 ]; then
    echo "WARNING: Unable to copy imageFiles/tmp_passwords/archiva_admin_pw into container"
  else
    docker exec -i -t bidms-tomcat-dev /root/createArchivaAdminUser.sh admin /tmp/archiva_admin_pw
    if [ $? != 0 ]; then
      echo "WARNING: Unable to create Archiva admin user"
      # We can get away with not making this fatal
    else
      echo "Successfully created Archiva admin user"

      # Get the login cookie and the xsrf token so we can do things as the
      # logged in admin
      cookieAndToken=$(docker exec -i -t bidms-tomcat-dev /root/archivaAdminLogin.sh)
      cookie=$(echo "$cookieAndToken"|cut -d";" -f1)
      token=$(echo "$cookieAndToken"|cut -d";" -f2)
      if [ $? != 0 ]; then
        echo "WARNING: Unable to login as the Archiva admin user"
      else
        echo "Successfully logged in as Archiva admin user"
        echo "Using cookie $cookie and token $token"
    
        docker cp imageFiles/tmp_passwords/archiva_bidms-build_pw bidms-tomcat-dev:/tmp
        if [ $? != 0 ]; then
          echo "WARNING: Unable to copy imageFiles/tmp_passwords/archiva_bidms-build_pw into container"
        else
          docker exec -i -t bidms-tomcat-dev /root/createArchivaUser.sh "$cookie" "$token" "bidms-build" "BIDMS Builder" "bidmsbuilder@localhost.bogus" /tmp/archiva_bidms-build_pw
          if [ $? != 0 ]; then
            echo "WARNING: Unable to create Archiva bidms-builder user"
          else
            echo "Successfully created Archiva bidms-builder user"

            # add roles so user can deploy
            docker exec -i -t bidms-tomcat-dev /root/addInternalRepoManagerRolesForUser.sh "$cookie" "$token" "bidms-build"
            if [ $? != 0 ]; then
              echo "WARNING: Unable to add roles for Archiva bidms-builder user"
            else
              echo "Successfully added roles for Archiva bidms-builder user"
            fi
          fi
          docker exec -i -t bidms-tomcat-dev rm -f /tmp/archiva_bidms-build_pw
        fi
      fi
    fi
    docker exec -i -t bidms-tomcat-dev rm -f /tmp/archiva_admin_pw
  fi
  
  echo "Stopping Tomcat"
  docker exec -i -t bidms-tomcat-dev /etc/init.d/tomcat8 stop

  echo "$HOST_ARCHIVA_DIRECTORY does not yet exist.  Copying from temporary location."
  echo "You must have sudo access for this to work and you may be prompted for a sudo password."
  sudo cp -pr $TMP_ARCHIVA_HOST_DIR $HOST_ARCHIVA_DIRECTORY
  if [ $? != 0 ]; then
    echo "copy from $TMP_ARCHIVA_HOST_DIR to $HOST_ARCHIVA_DIRECTORY failed"
    echo "Stopping the container."
    ./stopContainer.sh
    exit 1
  fi
  echo "Successfully copied to $HOST_ARCHIVA_DIRECTORY"
else
  echo "$HOST_ARCHIVA_DIRECTORY on the host already exists.  Not copying anything."
  echo "If you want a clean install, delete $HOST_ARCHIVA_DIRECTORY and re-run this script."
fi

if [ ! -z "$startedContainer" ]; then
  echo "Stopping the container."
  ./stopContainer.sh || check_exit
fi
