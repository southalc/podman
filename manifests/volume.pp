# @summary Create a podman volume with defined flags
#
# @param ensure [String]
#   State of the resource must be either 'present' or 'absent'.
#
# @param flags [Hash]
#   All flags for the 'podman volume create' command are supported as part of the
#   'flags' hash, using only the long form of the flag name.  The value for any
#   defined flag in the 'flags' hash must be entered as a string.
#   Volume names are created based on the resoure title (namevar)
#
# @param user String
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
  String $ensure  = 'present',
  Hash $flags     = {},
  String $user    = '',
) {
  # Convert $flags hash to command arguments
  $_flags = $flags.reduce('') |$mem, $flag| {
    "${mem} --${flag[0]} \"${flag[1]}\""
  }

  if $user != '' {
    ensure_resource('podman::rootless', $user, {})

    # Set execution environment for the rootless user
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
      environment => [
        "HOME=${User[$user]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$user]['uid']}",
      ],
      cwd         => User[$user]['home'],
      provider    => 'shell',
      user        => $user,
      require     => [
        Podman::Rootless[$user],
        Service['systemd-logind'],
      ],
    }
  } else {
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
    }
  }

  case $ensure {
    'present': {
      Exec { "podman_create_volume_${title}":
        command => "podman volume create ${_flags} ${title}",
        unless  => "podman volume inspect ${title}",
        *       => $exec_defaults,
      }
    }
    'absent': {
      Exec { "podman_remove_volume_${title}":
        command => "podman volume rm ${title}",
        unless  => "test ! $(podman volume inspect ${title})",
        *       => $exec_defaults,
      }
    }
    default: {
      fail('"ensure" must be "present" or "absent"')
    }
  }
}

