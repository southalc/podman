# @summary Creates the Varlink Socket for Podman
#
# @param ensure [String]
#   State of the resource must be either 'present' or 'absent'.
#
# @param socket [String]
#    Path to where the podman socket should be configured to run
#
# @param user [String]
#    Who should own the socket directory and socket
#
# @param group [String]
#    Which group should own the socket directory and socket
#
# @param socket_mode [String]
#    permissions applied to the socket
#
define podman::varlink (
  String $ensure      = 'present',
  String $socket      = '/run/podman/io.podman',
  String $user        = 'root',
  String $group       = 'root',
  String $socket_mode = '0750',
) {

  # write temp file config
  $working_directory = join(split($socket, "/")[0,-2], "/")
  $contents = "d ${working_directory} ${socket_mode} ${user} ${group}"
  file { "/etc/tmpfiles.d/podman.conf" :
      ensure  => $ensure,
      content => "${contents}",
      owner   => "root",
      group   => "root"
  }

  # systemd helpers
  exec { "podman-systemd-refresh":
      command     => "/usr/bin/systemctl daemon-reload",
      refreshonly => true,
  }
  exec { "podman-systemd-tmpfiles-refresh" :
      command     => "/usr/bin/systemd-tmpfiles --create --no-pager",
      refreshonly => true,
  }

  # install service file
  file { "/etc/systemd/system/io.podman.socket" :
      ensure  => $ensure,
      content => template("${module_name}/io.podman.socket.erb"),
      notify  => [Exec["podman-systemd-refresh"], Exec["podman-systemd-tmpfiles-refresh"]]
  }

  if $ensure == 'present' {
      $svc_ensure = 'running'
      $svc_enable = true
  } else {
      $svc_ensure = 'stopped'
      $svc_enable = false
  }

  service { "io.podman.socket" :
      ensure  => $svc_ensure,
      enable  => $svc_enable,
      require => [File["/etc/systemd/system/io.podman.socket"]]
  }

}
