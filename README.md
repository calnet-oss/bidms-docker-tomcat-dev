## Purpose

This [Docker](http://www.docker.com/) image extends the [base BIDMS Tomcat
image](http://www.github.com/calnet-oss/bidms-docker-tomcat-base) to add web
applications to the Tomcat container that are relevant for development of
BIDMS.  These are web applications that are internal to the development team
(or just a single developer) and typically not deployed publicly.

Development applications installed in this image:
* [Archiva](http://archiva.apache.org/) - A maven repository and proxy. 
  This is used to deploy BIDMS builds locally.

The author does not currently publish the image in any public Docker
repository but a script, described below, is provided to easily create your
own image.

## License

The source code, which in this project is primarily shell scripts and the
Dockerfile, is licensed under the [BSD two-clause license](LICENSE.txt).

## Building the Docker image

Copy `config.env.template` to `config.env` and edit to set config values.

Create the `imageFiles/tmp_passwords/archiva_admin_pw` file and set an
Archiva admin password, which allows you to authenticate into the Archiva
web application.  Also create the
`imageFiles/tmp_passwords/archiva_bidms-build_pw` file and set a password
for the `bidms-build` Archiva user, which will be used to deploy builds to
Archiva.

Make sure they are only readable by the owner:
```
chmod 600 imageFiles/tmp_passwords/archiva_admin_pw \
  imageFiles/tmp_passwords/archiva_bidms-build_pw
```

Generate the key pair that Tomcat will use for TLS:
```
./generateTLSCert.sh
```

Two files are generated:
* `imageFiles/tmp_tomcat/tomcat.jks` - The Java keystore used by Tomcat.
* `imageFiles/tmp_tomcat/tomcat_pubkey.pem` - Tomcat's TLS public key.

This image depends on the the base BIDMS Tomcat Docker image from the
[bidms-docker-tomcat-base](http://www.github.com/calnet-oss/bidms-docker-tomcat-base)
project.  If you don't have that image built yet, you'll need that first.

Make sure the `HOST_ARCHIVA_DIRECTORY` directory specified in `config.env`
does not exist yet on your host machine (unless you're running
`buildImage.sh` subsequent times and want to keep your existing run files)
so that the build script will initialize your application server.

Build the container image:
```
./buildImage.sh
```

## Installing the Docker network bridge

This container requires the `bidms_nw` [user-defined Docker network
bridge](https://docs.docker.com/engine/userguide/networking/#bridge-networks)
before running.  If you have not yet created this network bridge on your
host (only needs to be done once), do so by running:
```
./createNetworkBridge.sh
```

If you don't remember if you have created this bridge yet, you can check by
issuing the following command (you should see `bidms_nw` listed as one of
the named networks):
```
docker network ls
```

## Running

To run the container interactively (which means you get a shell prompt):
```
./runContainer.sh
```

Or to run the container detached, in the background:
```
./detachedRunContainer.sh
```

If everything goes smoothly, the container should expose several https
ports.

If running interactively, you can exit the container by exiting the bash
shell.  If running in detached mode, you can stop the container with:
`docker stop bidms-tomcat-dev` or there is a `stopContainer.sh` script
included to do this.

To inspect the running container from the host:
```
docker inspect bidms-tomcat-dev
```

To list the running containers on the host:
```
docker ps
```

## Tomcat Ports

In addition to the base Tomcat ports already exposed, this container exposes
additional ports for development-related applications.  These ports are
redirected to ports on the host, where the host port numbers are specified
in `config.env`.
  * LOCAL_ARCHIVA_TOMCAT_PORT (default: 8360)
    * Archiva maven repository and proxy

## Tomcat File Persistence

Docker will mount the host directory specified in `HOST_TOMCAT_DIRECTORY`
from `config.env` within the container as `/var/lib/tomcat8` and this is how
the application server run files are persisted across container runs.

As mentioned in the build image step, the `buildImage.sh` script will
initialize the Tomcat run files as long as the `HOST_TOMCAT_DIRECTORY`
directory doesn't exist yet on the host at the time `buildImage.sh` is run. 
Subsequent runs of `buildImage.sh` will not re-initialize these files if
the directory already exists.

If you plan on running the image on hosts separate from the machine you're
running the `buildImage.sh` script on then you'll probably want to let
`buildImage.sh` initialize the run files and then copy the
`HOST_TOMCAT_DIRECTORY` to all the machines that you will be running the
image on.  When copying, be careful about preserving file permissions.

## Archiva File Persistence

Docker will mount the host directory specified in `HOST_ARCHIVA_DIRECTORY`
from `config.env` within the container as `/usr/local/archiva` and this is
how the Archiva data files are persisted across container runs.

The same initialization steps apply to this as the steps outlined for
`HOST_TOMCAT_DIRECTORY`.

## Default Archiva Users

During the `buildImage.sh` initialization step for the
`HOST_ARCHIVA_DIRECTORY`, the script attempts to create a couple of default
users within Archiva.
* `admin` - The administrator account
  * Password contained in `imageFiles/tmp_passwords/archiva_admin_pw`.  This
    file must be created by you before running `buildImage.sh` (assuming
    `HOST_ARCHIVA_DIRECTORY` doesn't exist and you're initializing).
* `bidms-build` - The account used by the build scripts to deploy artifacts
  to Archiva.
  * Password contained in `imageFiles/tmp_passwords/archiva_bidms-build_pw`. 
    This file must be created by you before running `buildImage.sh`
    (assuming `HOST_ARCHIVA_DIRECTORY` doesn't exist and you're
    initializing).

If the script wasn't able to create these default users, the script will
warn on the error, but still exit cleanly, so check the `buildImage.sh`
output to confirm these accounts were added successfully.
