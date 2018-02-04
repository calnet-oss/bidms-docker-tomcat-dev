#!/bin/bash

#
# Copyright (c) 2018, Regents of the University of California and
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

function get_archiva_title {
  html_title=$(wget --no-check-certificate --quiet https://localhost:8560/ -t 1 --timeout=10 -O -|egrep -o "<title>[^<]+</title>")
}

function startup_tomcat {
  echo "Starting up Tomcat"
  echo "#!/bin/sh" > /tmp/startup.sh
  echo "export CATALINA_HOME=/usr/share/tomcat8" >> /tmp/startup.sh
  echo "export CATALINA_BASE=/var/lib/tomcat8" >> /tmp/startup.sh
  echo "export CATALINA_TMPDIR=/tmp/tomcat" >> /tmp/startup.sh
  echo "export JAVA_OPTS=\"-Djava.awt.headless=true -XX:+UseConcMarkSweepGC -Djava.net.preferIPv4Stack=true -Dgrails.env=development -Dregistry.config.location=/var/lib/tomcat8/registry -Dhazelcast.config=/etc/tomcat8/hazelcast.xml -Dappserver.base=/usr/local/archiva -Dappserver.home=/usr/local/archiva -Dderby.system.home=/usr/local/archiva/derby -Dcatalina.logdir=/tmp -Xmx3072M\"" >> /tmp/startup.sh
  echo "/usr/share/tomcat8/bin/startup.sh" >> /tmp/startup.sh
  chmod +x /tmp/startup.sh
  sudo -u tomcat8 mkdir /tmp/tomcat
  sudo -u tomcat8 /tmp/startup.sh
  if [ $? != 0 ]; then
    echo "Tomcat failed to start up" > /dev/stderr
    exit 1
  fi
}

function shutdown_tomcat {
  echo "Shutting down Tomcat"
  echo "#!/bin/sh" > /tmp/shutdown.sh
  echo "export CATALINA_HOME=/usr/share/tomcat8" >> /tmp/shutdown.sh
  echo "export CATALINA_BASE=/var/lib/tomcat8" >> /tmp/shutdown.sh
  echo "export CATALINA_TMPDIR=/tmp/tomcat" >> /tmp/shutdown.sh
  echo "/usr/share/tomcat8/bin/shutdown.sh" >> /tmp/shutdown.sh
  chmod +x /tmp/shutdown.sh
  sudo -u tomcat8 /tmp/shutdown.sh
  rm -f /tmp/shutdown.sh
}

#sudo cp -pr /usr/local/archiva /usr/local/archiva_tmp

startup_tomcat

echo "Sleeping 45 seconds to let Tomcat start"
sleep 45

echo "Waiting for Archiva server to start responding"
get_archiva_title
archiva_counter=0
until [[ "$html_title" = "<title>Apache Archiva</title>" || $archiva_counter -gt 9 ]]; do
  let archiva_counter+=1
  echo "Archiva not started.  Sleeping 10 seconds until next try ($archiva_counter of 10)."
  sleep 10
  get_archiva_title
done

if [ "$html_title" != "<title>Apache Archiva</title>" ]; then
  echo "Failure waiting for Archiva to start" > /dev/stderr
  exit 1
else
  echo "Archiva is started"
fi

function initialize_archiva {
  if [ ! -e /tmp/tmp_passwords/archiva_admin_pw ]; then
    echo "/tmp/tmp_passwords/archiva_admin_pw does not exist" > /dev/stderr
    exit 1
  fi
  /root/createArchivaAdminUser.sh admin /tmp/tmp_passwords/archiva_admin_pw
  if [ $? != 0 ]; then
    echo "Unable to create Archiva admin user" > /dev/stderr
    exit 1
  else
    echo "Successfully created Archiva admin user"

    # Get the login cookie and the xsrf token so we can do things as the
    # logged in admin
    cookieAndToken=$(/root/archivaAdminLogin.sh)
    if [ $? != 0 ]; then
      echo "Unable to login as the Archiva admin user" > /dev/stderr
      exit 1
    else
      cookie=$(echo "$cookieAndToken"|cut -d";" -f1)
      token=$(echo "$cookieAndToken"|cut -d";" -f2)
      echo "Successfully logged in as Archiva admin user"
      echo "Using cookie $cookie and token $token"
      if [ ! -e /tmp/tmp_passwords/archiva_bidms-build_pw ]; then
        echo "/tmp/tmp_passwords/archiva_bidms-build_pw does not exist" > /dev/stderr
        exit 1
      fi
      /root/createArchivaUser.sh "$cookie" "$token" "bidms-build" "BIDMS Builder" "bidmsbuilder@localhost.bogus" /tmp/tmp_passwords/archiva_bidms-build_pw
      if [ $? != 0 ]; then
        echo "Unable to create Archiva bidms-builder user" > /dev/stderr
        exit 1
      else
        echo "Successfully created Archiva bidms-builder user"

        # add roles so user can deploy
        /root/addInternalRepoManagerRolesForUser.sh "$cookie" "$token" "bidms-build"
        if [ $? != 0 ]; then
          echo "Unable to add roles for Archiva bidms-builder user" > /dev/stderr
          exit 1
        else
          echo "Successfully added roles for Archiva bidms-builder user"
        fi
      fi
    fi
  fi
}

initialize_archiva

shutdown_tomcat

echo "Sleeping 20 seconds to wait for Tomcat to fully shut down"
sleep 20
#sudo cp -pr /usr/local/archiva_tmp/* /usr/local/archiva
