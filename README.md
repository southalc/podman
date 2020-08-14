# podman

#### Table of Contents

1. [Description](#description)
2. [Setup - The basics of getting started with podman](#setup)
3. [Usage - Configuration options and additional functionality](#usage)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Description

Podman enables running standard docker containers without the usual docker daemon.  This has some benefits from a security
perspective, with the key point of enabling containers to run as an unprivileged user.  Podman also has the concept of a 'pod',
which is a shared namespace where multiple containers can be deployed and communicate with each other over the loopback
address of 127.0.0.1

The defined types 'pod', 'image', 'volume', and 'container' are essentially wrappers around the respective podman "create"
commands (`podman <type> create`).  The defined types support all flags for the command, but require them to be expressed
using the long form (`--env` instead of `-e`).  Flags that don't have values should set the value to an empty string.  Flags
that may be used more than once should be expressed as an array.  The Jenkins example configuration below demonstrates some
of this in the `flags` and `service_flags` hashes.

## Setup

The module installs packages including 'podman', 'skopeo', and 'podman-docker'.  The 'podman' package provides core functionality
for running containers, while 'skopeo' is used to check for container image updates, and 'podman-docker' provides a 'docker'
command for those that are used to typing 'docker' instead of 'podman' (the 'podman' command is purposefully compatible with 'docker').

Simply including the module is enough to install the packages.  There is no service associated with podman, so the module just
installs the packages.  Management of 'pods', 'images', 'volumes', and 'containers' is done using defined types.  The module's
defined types are all implemented in the main 'podman' class, allowing resources to be declared as hiera hashes.  See the
[reference](REFERENCE.md) for usage of the defined types.

## Usage

Assign the module to node(s):
```
include podman
```
With the module assigned you can manage resources using hiera data.  When the podman defined types are called with the `user`
and `homedir` parameters the resources will be owned by the defined user to support rootless containers.
This example:
* Creates volume `jenkins`
* Creates container `jenkins` using the defined image
* Sets container flags to label the container, publish ports, and attach the volume
* Set service flags for the systemd service to timeout at 60 seconds
* The volume and container are both created as user `jenkins`, and the systemd service will run as this same user
* A systemd service `podman-<user>-<container_name>` is created, enabled, and started
* The container will be re-deployed any time the image source digest does not match the running container image
because the default defined type setting for `podman::container::update` value is `true`.
```
podman::volumes:
  jenkins:
    user: jenkins
    homedir: /home/jenkins
podman::containers:
  jenkins:
    user: jenkins
    homedir: /home/jenkins
    image: 'docker.io/jenkins/jenkins:lts'
    flags:
      label:
        - purpose=test
      publish:
        - '8080:8080'
        - '50000:50000'
      volume: 'jenkins:/var/jenkins_home'
    service_flags:
      timeout: '60'
    require:
      - Podman::Volume[jenkins]
```

## Limitations

The module was written and tested with RedHat/CentOS, but should work with any distribution where the podman and skopeo
packages are available.

## Development

I'd appreciate any feedback.  To contribute to development, fork the source and submit a pull request.

