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
FROM bidms/tomcat

ARG APT_PROXY_URL=
RUN if [ ! -z "$APT_PROXY_URL" ]; then echo "Acquire::http::Proxy \"$APT_PROXY_URL\";" > /etc/apt/apt.conf.d/00aptproxy; else echo "not using apt proxy"; fi

ARG TOMCAT_VERSION=8

RUN set -x \
  && export DEBIAN_FRONTEND=noninteractive \
  && apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/*

# Copy the keystore for TLS
COPY tmp_tomcat/tomcat.jks /etc/tomcat${TOMCAT_VERSION}/certs
COPY tmp_tomcat/tomcat_pubkey.pem /etc/tomcat${TOMCAT_VERSION}/certs
RUN chmod 600 /etc/tomcat${TOMCAT_VERSION}/certs/tomcat.jks \
  && chown tomcat${TOMCAT_VERSION}:tomcat${TOMCAT_VERSION} \
       /etc/tomcat${TOMCAT_VERSION}/certs/tomcat.jks \
       /etc/tomcat${TOMCAT_VERSION}/certs/tomcat_pubkey.pem

ARG ARCHIVA_VERSION=2.2.3
RUN set -x \
  && wget "https://www.apache.org/dist/archiva/${ARCHIVA_VERSION}/binaries/apache-archiva-${ARCHIVA_VERSION}.war.sha1" \
       -O /tmp/archiva.war.sha1 \
  && wget "http://www-us.apache.org/dist/archiva/${ARCHIVA_VERSION}/binaries/apache-archiva-${ARCHIVA_VERSION}.war" \
       -O /tmp/archiva.war \
  && test "$(sha1sum /tmp/archiva.war|cut -d' ' -f1)" = "$(cat /tmp/archiva.war.sha1|cut -d' ' -f1)" \
  && rm -f /tmp/archiva.war.sha1

# Archiva needs activation.jar and mail.jar in the Tomcat common lib directory
ARG JAVA_MAIL_VERSION=1.4.7
ARG JAVA_ACTIVATION_VERSION=1.1.1
RUN mkdir /usr/local/tomcat/common-lib
RUN wget "https://repo1.maven.org/maven2/javax/mail/mail/${JAVA_MAIL_VERSION}/mail-${JAVA_MAIL_VERSION}.jar" -O /usr/local/tomcat/common-lib/mail-${JAVA_MAIL_VERSION}.jar
RUN wget "https://repo1.maven.org/maven2/javax/activation/activation/${JAVA_ACTIVATION_VERSION}/activation-${JAVA_ACTIVATION_VERSION}.jar" -O /usr/local/tomcat/common-lib/activation-${JAVA_ACTIVATION_VERSION}.jar

# Archive needs Derby in the Tomcat common lib directory
ARG DERBY_VERSION=10.13.1.1
RUN set -x \
  && wget "https://archive.apache.org/dist/db/derby/db-derby-${DERBY_VERSION}/db-derby-${DERBY_VERSION}-bin.tar.gz.md5" -O /tmp/db-derby-${DERBY_VERSION}-bin.tar.gz.md5 \
  && wget "https://archive.apache.org/dist/db/derby/db-derby-${DERBY_VERSION}/db-derby-${DERBY_VERSION}-bin.tar.gz" -O /tmp/db-derby-${DERBY_VERSION}-bin.tar.gz \
  && test "$(md5sum /tmp/db-derby-${DERBY_VERSION}-bin.tar.gz|cut -d' ' -f1)" = "$(cat /tmp/db-derby-${DERBY_VERSION}-bin.tar.gz.md5|cut -d' ' -f1)" \
  && (cd /usr/local; tar xfz /tmp/db-derby-${DERBY_VERSION}-bin.tar.gz) \
  && ln -fs /usr/local/db-derby-${DERBY_VERSION}-bin /usr/local/db-derby-current \
  && touch /usr/local/tomcat/common-lib/DERBY_IS_${DERBY_VERSION} \
  && (cd /usr/local/db-derby-${DERBY_VERSION}-bin/lib; \
       cp -p derby.jar /usr/local/tomcat/common-lib; \
       cp -p derbyclient.jar /usr/local/tomcat/common-lib; \
       cp -p derbynet.jar /usr/local/tomcat/common-lib; \
       cp -p derbyLocale*.jar /usr/local/tomcat/common-lib) \
  && rm -f /tmp/db-derby-${DERBY_VERSION}-bin.tar.gz \
       /tmp/db-derby-${DERBY_VERSION}-bin.tar.gz.md5

COPY tmp_tomcat/ /tmp/tmp_tomcat/

# Add /usr/local/tomcat/common-lib to list of directories common JAR files
# are loaded from.
RUN set -x && /tmp/tmp_tomcat/addTomcatCommonPath.sh /etc/tomcat${TOMCAT_VERSION}/catalina.properties

# Install the Archiva WAR file
RUN set -x \
  && mkdir /usr/local/tomcat/webapps/archiva \
       /etc/tomcat${TOMCAT_VERSION}/CatalinaArchiva \
  && chown tomcat${TOMCAT_VERSION}:tomcat${TOMCAT_VERSION} \
       /usr/local/tomcat/webapps/archiva \
       /etc/tomcat${TOMCAT_VERSION}/CatalinaArchiva \
  && mv /tmp/archiva.war \
       /usr/local/tomcat/webapps/archiva/ROOT.war \
  && chown tomcat${TOMCAT_VERSION}:tomcat${TOMCAT_VERSION} /usr/local/tomcat/webapps/archiva/ROOT.war \
  && echo "ARCHIVA_VERSION=${ARCHIVA_VERSION}" > /usr/local/tomcat/webapps/archiva/archiva.properties \
  && sed -f /tmp/tmp_tomcat/server_archiva_objects.sed \
       -i /etc/tomcat${TOMCAT_VERSION}/server.xml

# Archiva needs some system properties
RUN set -x \
  && mkdir -p /usr/local/archiva \
  && mkdir /usr/local/archiva/conf \
       /usr/local/archiva/derby \
  && chown -R tomcat${TOMCAT_VERSION}:tomcat${TOMCAT_VERSION} /usr/local/archiva \
  && echo "\n# For Archiva" >> /etc/default/tomcat${TOMCAT_VERSION} \
  && echo "JAVA_OPTS=\"\$JAVA_OPTS -Dappserver.base=/usr/local/archiva -Dappserver.home=/usr/local/archiva -Dderby.system.home=/usr/local/archiva/derby\"" >> /etc/default/tomcat${TOMCAT_VERSION}

# Archiva needs a ROOT.xml context file that contains required JNDI objects
RUN mkdir /etc/tomcat${TOMCAT_VERSION}/CatalinaArchiva/localhost-archiva \
  && chown tomcat${TOMCAT_VERSION}:tomcat${TOMCAT_VERSION} /etc/tomcat${TOMCAT_VERSION}/CatalinaArchiva/localhost-archiva
COPY tmp_tomcat/archiva/ROOT.xml /etc/tomcat${TOMCAT_VERSION}/CatalinaArchiva/localhost-archiva/ROOT.xml

# Add the default archiva configuration.  This includes some default
# repositories.
COPY archiva_config/archiva.xml /usr/local/archiva/conf/archiva.xml
RUN chown tomcat${TOMCAT_VERSION}:tomcat${TOMCAT_VERSION} \
      /usr/local/archiva/conf/archiva.xml \
  && chmod 640 /usr/local/archiva/conf/archiva.xml

COPY root/ /root/

# Replace the admin password in the admin login script
COPY tmp_passwords/archivaAdminLogin.sed /tmp/tmp_passwords/
COPY tmp_passwords/archiva_admin_pw /tmp/tmp_passwords/
COPY tmp_passwords/archiva_bidms-build_pw /tmp/tmp_passwords/
RUN sed -f /tmp/tmp_passwords/archivaAdminLogin.sed -i /root/archivaAdminLogin.sh

# Initialize Archiva with users
COPY initializeArchiva.sh /tmp/
RUN set -x && /tmp/initializeArchiva.sh

RUN rm -rf /core /tmp/*

# webapps-archiva
EXPOSE 8560

ENTRYPOINT ["/etc/container/tomcat-entrypoint.sh", "interactive"]

# We've commented this out because this image is used as a base for other
# images and Docker doesn't do what we want when we go to update
# /usr/local/archiva in child images if we specify a VOLUME in the parent.
# If you want this, uncomment here and set USE_HOST_VOLUMES=1 in config.env.
#VOLUME /usr/local/archiva
