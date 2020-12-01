# @summary
#   Enable rootless podman containers to run as a systemd user service.
#
define podman::rootless {
  $uid  = User[$title]['uid']
  $gid  = User[$title]['gid']

  $command = @("END"/$)
    if [[ \$(loginctl show-user ${title} --property=Linger) != 'Linger=yes' ]]
      then
      loginctl enable-linger ${title}
    fi
    if [[ -d /run/user/${uid} ]]
      then
      mkdir -m 700 -p /run/user/${uid}
      chown ${uid}:${gid} /run/user/${uid}
    fi
    |END

  Exec { "loginctl_linguer_${title}":
    path     => '/sbin:/usr/sbin:/bin:/usr/bin',
    command  => $command,
    provider => 'shell',
    unless   => "test $(loginctl show-user ${title} --property=Linger) == 'Linger=yes'",
    require  => User[$title],
  }

  ensure_resource('Service', 'systemd-logind', { ensure => 'running', enable => true } )

  # Ensure the systemd directory tree exists for user services
  ensure_resource('File', [
    "${User[$name]['home']}/.config",
    "${User[$name]['home']}/.config/systemd",
    "${User[$name]['home']}/.config/systemd/user"
    ], {
    ensure  => directory,
    owner   => "${User[$name]['uid']}",
    group   => "${User[$name]['gid']}",
    mode    => '0750',
    require => File["${User[$name]['home']}"],
    }
  )
}

