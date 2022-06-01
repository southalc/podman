# @summary Enable a given user to run rootless podman containers as a systemd user service.
#
define podman::rootless {
  exec { "loginctl_linger_${name}":
    path     => '/sbin:/usr/sbin:/bin:/usr/bin',
    command  => "loginctl enable-linger ${name}",
    provider => 'shell',
    unless   => "test $(loginctl show-user ${name} --property=Linger) = 'Linger=yes'",
    require  => User[$name],
    notify   => Service['systemd-logind'],
  }
  ensure_resource('Service', 'podman systemd-logind', { name => 'systemd-logind.service', ensure => 'running' } )

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

  exec { "start_${name}.slice":
    path    => $facts['path'],
    command => "machinectl shell ${name}@.host '/bin/true'",
    unless  => "systemctl is-active user-${User[$name]['uid']}.slice",
    require => [
      Exec["loginctl_linger_${name}"],
      Service['systemd-logind'],
      File["${User[$name]['home']}/.config/systemd/user"],
    ],
  }

  if $podman::enable_api_socket {
    exec { "podman rootless api socket ${name}":
      command     => 'systemctl --user enable --now podman.socket',
      path        => $facts['path'],
      user        => $name,
      environment => [
        "HOME=${User[$name]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$name]['uid']}",
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${User[$name]['uid']}/bus",
      ],
      unless      => 'systemctl --user status podman.socket',
      require     => [
        Exec["loginctl_linger_${name}"],
        Exec["start_${name}.slice"],
      ],
    }
  }
}
