# Changelog

## Release 0.7.0
  - Added the quadlet defined type
  - Use puppet-systemd to manage rootless users

## Release 0.6.7
  - Bugfix. Avoid deprecated has_key function #64. Contributed by traylenator
  - Support for Puppet 8.x & puppetlabs/stdlib 9.x #66

## Release 0.6.6
 - Bugfix. Update install.pp due to false positive on selinux check #60. Contributed by magarvo
 - Support ArchLinux #61. Contributed by traylenator
 - Update supported OS list to drop specific versioned releases.
 
## Release 0.6.5

 - Bugfix for issue #55, Typo in network manifest. Identified by CyberLine
 - Bugfix for issue #56, creates invalid systemd service file. Identified by tuxmaster5000

## Release 0.6.4

 - Bugfix. Fixed spelling typo "machienectl", which changed module parameters:
  "machienectl_pkg_ensure" is now "machinectl_pkg_ensure"
  "machienectl_pkg" is now "machinectl_pkg"
 - Bugfix for issue #54. Unable to set the "--new" option when the systemd unit will be
   created. identified by tuxmaster5000

## Release 0.6.3

 - Add user option for networks #53. Contributed by jaevans
 - Bugfix for manage_subuid documentation/implementation mismatch #51. Identified by ja391045

## Release 0.6.2

- Bugfix. Fix service name #49. contributed by jcpunk

## Release 0.6.1

- Bugfix. Set "systemd-logind" service title to a unique value to avoid conflict with "puppet-systemd"
  PR #45, contributed by jcpunk

## Release 0.6.0

- Start user.slice if not running before trying to use "systemctl --user" PR #42, contributed by jcpunk
- Bugfix. Check for the container to avoid refresh errors. PR #43, contributed by jcpunk

## Release 0.5.7

- Bugfix. Revert "remove rootless_users parameter and users resource collector" Contributed by silug

## Release 0.5.6

- No functional changes.  Bumped module dependencies to include the latest versions.  Suggested by yorickps

## Release 0.5.5

- Remove rootless_users parameter from the main class and do not use a resource collector for users. Identified by imp-

## Release 0.5.4

- Bugfix. Creating multiple instances of podman::rootless fails, because they all have the same title for the api socket exec.
  Contributed by dmaes

## Release 0.5.3

- Minor refactoring and general cleanup across several manifests.
- All module parameters defined in the main class and referenced by other classes.
- Default values moved from module hiera to main manifest.
- Add ability to manage the podman-compose package.  Contributed by coreone

## Release 0.5.2

- Minor fixes to the 'podman::network' defined type.  Contributed by optizor

## Release 0.5.1

- In the container defined type, skip the upstream image check when the running container image matches the
  declared resource and $update is false.  This reduces hits against the image registry.  Contributed by jaevans
- Fix operator syntax used by 'loginctl show-user' command to work with strict POSIX shells.  Identified by drebs
- Add a $ruby parameter to the container defined type.  This enables open source puppet agents where the ruby
  binary is not in the under /opt/puppetlabs.  Contributed by jaevans

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
