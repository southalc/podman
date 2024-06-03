# @summary Enable a given user to run rootless podman containers as a systemd user service.
#
define podman::rootless {
  exec { "loginctl_linger_${name}":
    path     => '/sbin:/usr/sbin:/bin:/usr/bin',
    command  => "loginctl enable-linger ${name}",
    provider => 'shell',
    unless   => "test $(loginctl show-user ${name} --property=Linger) = 'Linger=yes'",
    require  => User[$name],
    notify   => Service['podman systemd-logind'],
  }
  ensure_resource('Service', 'podman systemd-logind', { name => 'systemd-logind.service', ensure => 'running' })

  # Ensure the systemd directory tree exists for user services
  ensure_resource('File', [
      "${User[$name]['home']}/.config",
      "${User[$name]['home']}/.config/systemd",
      "${User[$name]['home']}/.config/systemd/user",
      "${User[$name]['home']}/.config/containers",
      "${User[$name]['home']}/.config/containers/systemd",
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
      Service['podman systemd-logind'],
      File["${User[$name]['home']}/.config/systemd/user"],
    ],
  }

  # Use https://github.com/voxpupuli/puppet-systemd/pull/443 once available
  exec { "daemon-reload-${name}":
    command     => [
      'systemd-run', '--pipe' , '--wait', '--user', '--machine',"${name}@.host",
      '/usr/bin/systemctl', '--user', 'daemon-reload',
    ],
    refreshonly => true,
    path        => $facts['path'],
  }

  if $podman::enable_api_socket {
    exec { "podman rootless api socket ${name}":
      command     => 'systemctl --user enable --now podman.socket',
      path        => $facts['path'],
      user        => $name,
      unless      => 'systemctl --user status podman.socket',
      require     => [Exec["loginctl_linger_${name}"], Exec["start_${name}.slice"]],
      environment => [
        "HOME=${User[$name]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$name]['uid']}",
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${User[$name]['uid']}/bus",
      ],
    }
  }
}
