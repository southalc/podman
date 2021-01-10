# podman

#### Table of Contents

1. [Description](#description)
2. [Setup - Getting started with podman](#setup)
3. [Usage - Configuration options and additional functionality](#usage)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Description

Podman enables running standard docker containers without the usual docker daemon.  This has some benefits from a security
perspective, with the key point of enabling containers to run as an unprivileged user.  Podman also has the concept of a 'pod',
which is a shared namespace where multiple containers can be deployed and communicate with each other over the loopback
address of '127.0.0.1'.  Be aware when running rootless containers that published ports are not automatically added to the
host firewall.  Use another module like [firewalld](https://forge.puppet.com/modules/puppet/firewalld) to open ports on the
host and the inbound traffic will reach the rootless container.

The defined types 'pod', 'image', 'volume', and 'container' are essentially wrappers around the respective podman "create"
commands (`podman <type> create`).  The defined types support all flags for the command, but require them to be expressed
using the long form (`--env` instead of `-e`).  Flags that don't require values should set the value to undef (use `~` or
`null` in YAML).  Flags that are used more than once should be expressed as an array.  The Jenkins example configuration
below demonstrates some of this in the `flags` and `service_flags` hashes.

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
With the module assigned you can manage podman resources using hiera data.  When podman defined types are used with the `user`
parameter the resources will be owned by the defined user to support rootless containers.  Using rootless containers this
way also enables 'loginctl enable-linger' on the user so rootless containers can start and run automatically under the assigned
user account when the system boots.

#### General podman and systemd notes

Be aware of how to work with podman and systemd user services when running rootless containers.  First, you'll need to "su" to
the assigned user work with the user's containers and services.  The systemd and podman commands rely on the 'XDG_RUNTIME_DIR'
environment variable, so set it in the shell as follows:
```
su - <container_user>
export XDG_RUNTIME_DIR=/run/user/$(id -u)
```
Systemd user services use the same 'systemctl' commands, but with the `--user` flag.  As the container user with the environment
set, you an run podman and 'systemctl' commands.
```
podman container list [-a]

systemctl --user status podman-<container_name>
```

## Examples
The following example is a hiera-based role that leverages the [types](https://forge.puppet.com/modules/southalc/types) module
to manage some dependent resources, then uses this module to deploy a rootless Jenkins container.  Note that the environment
here is using hiera lookup for class assignments.  The example will perform the following configuration:

* Create the `jenkins` user, group, and home directory using the [types](https://forge.puppet.com/modules/southalc/types) module
* Manage the `/etc/subuid` and `/etc/subgid` files, creating entries for the `jenkins` user
* Use `loginctl` to `enable-linger` on the 'jenkins' user so the user's containers can run as a systemd user service
* Creates volume `jenkins` owned by user `jenkins`
* Creates container `jenkins` from the defined image source owned by user `jenkins`
* Sets container flags to label the container, publish ports, and attach the previously created `jenkins` volume
* Set service flags for the systemd service to timeout at 60 seconds
* A systemd service `podman-<container_name>` is created, enabled, and started that runs as a user service
* The container will be re-deployed any time the image source digest does not match the running container image
because the default defined type parameter `podman::container::update` defaults to `true`
* Creates a firewall rule on the host to allow connections to port 8080, which is published by the container.  The rule
is created with the `firewalld_port` type from the [firewalld module](https://forge.puppet.com/modules/puppet/firewalld),
using the [types module](https://forge.puppet.com/modules/southalc/types) again so it can be defined entirely in hiera.
```
---
# Hiera based role for Jenkins container deployment

classes:
  - types
  - podman
  - firewalld

types::types:
  - firewalld_port

types::user:
  jenkins:
    ensure: present
    forcelocal: true
    uid:  222001
    gid:  222001
    password: '!!'
    home: /home/jenkins
    
types::group:
  jenkins:
    ensure: present
    forcelocal: true
    gid:  222001

types::file:
  /home/jenkins:
    ensure: directory
    owner: 222001
    group: 222001
    mode: '0700'
    require: 'User[jenkins]'


podman::manage_subuid: true
podman::subid:
  '222001':
    subuid: 12300000
    count: 65535

podman::volumes:
  jenkins:
    user: jenkins

podman::containers:
  jenkins:
    user: jenkins
    image: 'docker.io/jenkins/jenkins:lts'
    flags:
      label:
        - purpose=dev
      publish:
        - '8080:8080'
        - '50000:50000'
      volume: 'jenkins:/var/jenkins_home'
    service_flags:
      timeout: '60'
    require:
      - Podman::Volume[jenkins]

types::firewalld_port:
  podman_jenkins:
    ensure: present
    zone: public
    port: 8080
    protocol: tcp
```
Several additional examples are in a separate [github project](https://github.com/southalc/r10k/tree/production/data/containers), including
a Traefik container configuration that enables SSL termination and proxy access to other containers running on the host, with a dynamic
configuration directory enabling updates to proxy rules as new containers are added and/or removed.

## Limitations

The module was written and tested with RedHat/CentOS, but should work with any distribution that uses systemd and includes
the podman and skopeo packages

## Development

I'd appreciate any feedback.  To contribute to development, fork the source and submit a pull request.

