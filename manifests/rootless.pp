# @summary
#   Enable rootless podman containers to run as a systemd user service.
#
define podman::rootless {
  include podman

  Exec { "loginctl_linger_${name}":
    path     => '/sbin:/usr/sbin:/bin:/usr/bin',
    command  => "loginctl enable-linger ${name}",
    provider => 'shell',
    unless   => "test $(loginctl show-user ${name} --property=Linger) == 'Linger=yes'",
    require  => User[$name],
  }
  ensure_resource('Service', 'systemd-logind', { ensure => 'running', enable => true } )

  # Ensure the systemd directory tree exists for user services
  ensure_resource('File', [
    "${User[$name]['home']}/.config",
    "${User[$name]['home']}/.config/systemd",
    "${User[$name]['home']}/.config/systemd/user"
    ], {
      ensure  => directory,
      owner   => $name,
      group   => "${User[$name]['gid']}",
      mode    => '0700',
      require => File["${User[$name]['home']}"],
    }
  )

  if $podman::enable_api_socket {
    exec { "/bin/bash -c 'XDG_RUNTIME_DIR=/run/user/$( id -u ) systemctl --user enable --now podman.socket'":
      path    => '/bin:/usr/bin',
      user    => $name,
      unless  => "/bin/bash -c 'XDG_RUNTIME_DIR=/run/user/$( id -u ) systemctl --user status podman.socket'",
      require => Exec["loginctl_linger_${name}"],
    }
  }
}
