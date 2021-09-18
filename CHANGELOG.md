# Changelog

## Release 0.5.0

- Add 'extra_env' as a parameter for the 'podman::image' class.  Enables proxy support for image pull. Contributed by Kotty666
- Add 'podman::network' defined type to manage podman networks.  Contributed by optiz0r

## Release 0.4.0

- Add management of the API socket. - Contributed by silug

## Release 0.3.0

- Add the ability to manage host system configuration of container storage in '/etc/containers/storage.conf'.
  Contrubuted by coreone

## Release 0.2.7

- Added basic unit tests
- Fixed regression to update container when image digest differs from repo and update is true.  Identified by lukashartl

## Release 0.2.6

- Fix for container image removal when $update is true.  Can't reference a container image after the
  container has been deleted...

## Release 0.2.5

- Fix container removal when set to 'absent'
- Fix to re-deploy container when the defined resource image is changed.  Previously, a container would
  not be re-deployed when the $update parameter was set to false, even when the image declared in the
  resource definition had changed as reported by 'lukashartl'.  This change enables leaving the $update
  parameter set to false and 'pinning' the container image to a specific version, updating only when
  specified from puppet.

## Release 0.2.4

- Fix "Container fails to restart when resource notified" reported by toreanderson

## Release 0.2.3

- Fix for flags that don't require values - Contributed by jtopper
- Add dependency for the podman::install class to defined types

## Release 0.2.2

* Only configure selinux on systems where it is enabled - Contributed by optiz0r
* Clean-up in 'podman::rootless'

## Release 0.2.1

* Updated default hiera lookup to use a deep merge for all hash parameters in the main `podman` class

## Release 0.2.0

* Changes to fix rootless containers.  Using the defined types with the `user` parameter now requires a
  corresponding puppet user resource that includes the 'uid', 'gid', and 'home' attributes.
* The 'homedir' parameter was removed from all defined types.  Defined types now directly reference attributes
  of the associated user resource and requires the user and home directory to be managed by puppet.
* Changed default value of `manage_subuid` to false.  Recommend managing subuid/subgid outside this module,
  although the functionality to manage subuid/subgid files is still present.
* Stopped using resource default statements in favor of defining attributes with a hash.
* Make the 'image' parameter required for the 'container' defined type only when 'ensure' set to 'present'
* Include support for puppet 7.x

## Release 0.1.4

* Added parameter to optionally create '/etc/containers/nodocker' - Contributed by coreone

## Release 0.1.3

* Added dependency for [puppetlabs/selinux_core](https://forge.puppet.com/puppetlabs/selinux_core) to enable
  SElinux boolean `container_manage_cgroup`

## Release 0.1.2

### New features
* Added the ability to manage subuid/subgid files.

## Release 0.1.0

* Initial Release
