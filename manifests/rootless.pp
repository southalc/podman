# @summary Enable a given user to run rootless podman containers as a systemd user service.
#
define podman::rootless {
  ensure_resource('Loginctl_user', $name, { linger => enabled })

  # These aren't needed for quadlets but are the older defined types
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

  # Create the user directory for rootless quadlet files
  ensure_resource(
    'File', [
      '/etc/containers/systemd',
      '/etc/containers/systemd/users',
      "/etc/containers/systemd/users/${User[$name]['uid']}"
    ],
    { ensure  => directory }
  )

  exec { "start_${name}.slice":
    path    => $facts['path'],
    command => "machinectl shell ${name}@.host '/bin/true'",
    unless  => "systemctl is-active user-${User[$name]['uid']}.slice",
    require => [
      Loginctl_user[$name],
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
        Loginctl_user[$name],
        Exec["start_${name}.slice"],
      ],
    }
  }
}
