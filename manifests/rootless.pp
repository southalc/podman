# @summary Enable a given user to run rootless podman containers as a systemd user service.
#
define podman::rootless {
  exec { "loginctl_linger_${name}":
    path     => '/sbin:/usr/sbin:/bin:/usr/bin',
    command  => "loginctl enable-linger ${name}",
    provider => 'shell',
    unless   => "test $(loginctl show-user ${name} --property=Linger) = 'Linger=yes'",
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
    exec { "podman rootless api socket ${name}":
      command => "/bin/bash -c 'XDG_RUNTIME_DIR=/run/user/$( id -u ) systemctl --user enable --now podman.socket'",
      path    => '/bin:/usr/bin',
      user    => $name,
      unless  => "/bin/bash -c 'XDG_RUNTIME_DIR=/run/user/$( id -u ) systemctl --user status podman.socket'",
      require => Exec["loginctl_linger_${name}"],
    }
  }

  if $podman::enable_autoupdate_timer {
    exec { "podman rootless podman-auto-update.timer ${name}":
      command     => 'systemctl --user enable podman-auto-update.timer',
      path        => '/bin:/usr/bin',
      user        => $name,
      environment => [
        "HOME=${User[$name]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$name]['uid']}",
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${User[$name]['uid']}/bus",
      ],
      unless      => 'systemctl --user is-enabled podman-auto-update.timer',
      require     => Exec["loginctl_linger_${name}"],
    }
  }
}
