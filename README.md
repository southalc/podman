# podman

#### Table of Contents

1. [Description](#description)
2. [Setup - Getting started with podman](#setup)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Examples - Example configurations](#examples)
5. [Limitations - OS compatibility, etc.](#limitations)
6. [Development - Guide for contributing to the module](#development)

## Description

Podman enables running standard docker containers without the usual docker daemon.  This has some benefits from a security
perspective, with the key point of enabling containers to run as an unprivileged user.  Podman also has the concept of a 'pod',
which is a shared namespace where multiple containers can be deployed and communicate with each other over the loopback
address of '127.0.0.1'.

Recent versions of podman include support for [quadlets](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) that
enable managing containers directly with systemd unit files and services.  This greatly simplies managing podman services and is
now supported by this module with the new 'quadlet' defined type that manages the systemd unit files are resulting services.

The defined types 'pod', 'image', 'volume', 'secret' and 'container' are essentially wrappers around the respective podman "create"
commands (`podman <type> create`).  The defined types support all flags for the command, but require them to be expressed
using the long form (`--env` instead of `-e`).  Flags that don't require values should set the value to undef (use `~` or
`null` in YAML).  Flags that are used more than once should be expressed as an array.  The Jenkins example configuration
below demonstrates some of this in the `flags` and `service_flags` hashes.

## Setup

The module installs packages including 'podman', 'skopeo', and optionally 'podman-docker'.  The 'podman' package provides
core functionality for running containers, while 'skopeo' is used to check for container image updates. The 'podman-docker'
package provides a 'docker' command for those that are used to typing 'docker' instead of 'podman' (the 'podman' command is
purposefully compatible with 'docker').

Simply including the module is enough to install the packages.  There is no service associated with podman, so the module just
installs the packages.  Management of 'pods', 'images', 'volumes', and 'containers' is done using defined types.  The module's
defined types are all implemented in the main 'podman' class, allowing resources to be declared as hiera hashes.  See the
[reference](REFERENCE.md) for usage of the defined types.

## Usage

Assign the module to node(s):

```puppet
include podman
```

With the module assigned you can manage podman resources using hiera data.  When podman defined types are used with the `user`
parameter the resources will be owned by the defined user to support rootless containers.  Using rootless containers this
way also enables 'loginctl enable-linger' on the user so rootless containers can start and run automatically under the assigned
user account when the system boots.

The module implements quadlet support by allowing the systemd unit file to be represented as a hash.  The only quirk with this
is that systemd unit files can have lines with duplicate keys while hashes must have unique keys.  To work around this you can
express hash keys with an array of values to producce the desired systemd unit file.  The following hiera data shows this with
the 'PublishPort' key.  Note that the rootless "jenkins" user must also be managed as a puppet resource with a UID and valid
subuid/subgid mappings - see the last example here for those resources.
```
podman::quadlets:
  jenkins-v0:
    quadlet_type: "volume"
    user: jenkins
    settings:
      Install:
        WantedBy: jenkins.service
  jenkins:
    user: jenkins
    settings:
      Container:
        Image: 'docker.io/jenkins/jenkins:lts'
        PublishPort:
          - '8080:8080'
          - '5000:5000'
        Environment: 'JENKINS_OPTS="--prefix=/jenkins"'
        Volume: "systemd-jenkins-v0:/var/jenkins_home"
      Service:
        TimeoutStartSec: 300
      Unit:
        Requires: "jenkins-v0-volume.service"
```

The remaining defined types in the moduel are still present and documented below, but the recommended way to managed containers
is with quadlets.

### General podman and systemd notes

Be aware of how to work with podman and systemd user services when running rootless containers.  The systemd and podman commands
rely on the 'XDG_RUNTIME_DIR' environment variable that is normally set during login by pam_systemd.  When you switch users this
value will likely need to be set in the shell as follows:

```sh
su - <container_user>
export XDG_RUNTIME_DIR=/run/user/$(id -u)
```

Systemd user services use the same 'systemctl' commands, but with the `--user` flag.  As the container user with the environment
set, you an run podman and 'systemctl' commands.

```sh
podman container list [-a]

systemctl --user status podman-<container_name>
```

### containerd configuration

This module also contains minimal support for editing the `containerd` configuration files that control some of the lower level
settings for how containers are created. Currently, the only supported configuration file is `/etc/containers/storage.conf`. You
should be able to set any of the settings with that file using the `$podman::storage_options` parameter. For example (if using Hiera):

```yaml
podman::storage_options:
  storage:
    rootless_storage_path: '"/tmp/containers-user-$UID/storage"'
```

**Note the use of double quotes inside single quotes above.** This is due to the way the [puppetlabs/inifile](https://github.com/puppetlabs/puppetlabs-inifile/) module works currently.

## Examples

The following example is a hiera-based role that leverages the [types](https://forge.puppet.com/modules/southalc/types) module
to manage some dependent resources, then uses this module to deploy a rootless Jenkins container.  Note that the environment
here is using hiera lookup for class assignments.  The example will perform the following configuration:

* Create the `jenkins` user, group, and home directory using the [types](https://forge.puppet.com/modules/southalc/types) module
* Manage the `/etc/subuid` and `/etc/subgid` files, creating entries for the `jenkins` user
* Use `loginctl` to `enable-linger` on the 'jenkins' user so the user's containers can run as a systemd user service
* Creates volume `jenkins` owned by user `jenkins`
* Creates container `jenkins` from the defined image source owned by user `jenkins`
* Creates secret `db_pass` with secret version and gives it to jenkins container as an environment variable.
* Sets container flags to label the container, publish ports, and attach the previously created `jenkins` volume
* Set service flags for the systemd service to timeout at 60 seconds
* A systemd service `podman-<container_name>` is created, enabled, and started that runs as a user service
* The container will be re-deployed any time the image source digest does not match the running container image
because the default defined type parameter `podman::container::update` defaults to `true`
* Creates a firewall rule on the host to allow connections to port 8080, which is published by the container.  The rule
is created with the `firewalld_port` type from the [firewalld module](https://forge.puppet.com/modules/puppet/firewalld),
using the [types module](https://forge.puppet.com/modules/southalc/types) again so it can be defined entirely in hiera.

```yaml
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

lookup_options:
  podman::secret::secret:
    convert_to: "Sensitive"
podman::secret:
  db_pass:
    user: jenkins
    secret: very
    label:
      - version=20230615

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
      secret:
        - 'db_pass,type=env,target=DB_PASS'
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

