# @summary Create a podman volume with defined flags
#
# @param ensure
#   State of the resource must be either 'present' or 'absent'.
#
# @param flags
#   All flags for the 'podman volume create' command are supported as part of the
#   'flags' hash, using only the long form of the flag name.  The value for any
#   defined flag in the 'flags' hash must be entered as a string.
#   Volume names are created based on the resoure title (namevar)
#
# @param user
#   Optional user for running rootless containers.  When using this parameter,
#   the user must also be defined as a Puppet resource and must include the
#   'uid', 'gid', and 'home'
#
# @example
#   podman::volume { 'myvolume':
#     flags => {
#       label => 'use=test, app=wordpress',
#     }
#   }
#
define podman::volume (
  String $ensure = 'present',
  Hash $flags    = {},
  String $user   = '',
) {
  require podman::install

  # Convert $flags hash to command arguments
  $_flags = $flags.reduce('') |$mem, $flag| {
    if $flag[1] =~ String {
      "${mem} --${flag[0]} '${flag[1]}'"
    } elsif $flag[1] =~ Undef {
      "${mem} --${flag[0]}"
    } else {
      $dup = $flag[1].reduce('') |$mem2, $value| {
        "${mem2} --${flag[0]} '${value}'"
      }
      "${mem} ${dup}"
    }
  }

  if $user != '' {
    ensure_resource('podman::rootless', $user, {})

    # Set execution environment for the rootless user
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
      environment => [
        "HOME=${User[$user]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$user]['uid']}",
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${User[$user]['uid']}/bus",
      ],
      cwd         => User[$user]['home'],
      provider    => 'shell',
      user        => $user,
      require     => [
        Podman::Rootless[$user],
        Service['podman systemd-logind'],
      ],
    }
  } else {
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
    }
  }

  case $ensure {
    'present': {
      exec { "podman_create_volume_${title}":
        command => "podman volume create ${_flags} ${title}",
        unless  => "podman volume inspect ${title}",
        *       => $exec_defaults,
      }
    }
    'absent': {
      exec { "podman_remove_volume_${title}":
        command => "podman volume rm ${title}",
        unless  => "podman volume inspect ${title}; test $? -ne 0",
        *       => $exec_defaults,
      }
    }
    default: {
      fail('"ensure" must be "present" or "absent"')
    }
  }
}

