# @summary defined type for container removal, typically invoked from "podman::container"
#
# === Parameters ===
#
# @param user String
#   Optional user for running rootless containers
#
# @param homedir String
#   The `homedir` parameter is required when `user` is defined.  Defining it
#   this way avoids using an external fact to lookup the home directory of
#   all users.
#
define podman::rm (
  String $user    = '',
  String $homedir = '',
){

  Exec { "podman_remove_container_${title}":
    path    => '/sbin:/usr/sbin:/bin:/usr/bin',
    # Try nicely to stop the container, but then insist
    command => @("END"),
               systemctl stop podman-${title} || podman container stop --time 60 ${title}
               podman container rm --force ${title}
               |END
    unless  => "podman container exists ${title} ; test $? -eq 1",
  }

  File { "/etc/systemd/system/podman-${title}.service":
    ensure => absent,
    notify => Exec['podman_systemd_reload'],
  }
}
