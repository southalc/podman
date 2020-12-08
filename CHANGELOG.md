# Changelog

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
