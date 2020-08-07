# podman::volume - Create a podman volume with defined flags
#
# All flags for the 'podman volume create' command are supported as part of the
# 'flags' hash, using only the long form of the flag name.  The value for any
# defined flag in the 'flags' hash must be entered as a string.
# 
# Volume names are created based on the resoure title (namevar)
#
# @example
#   podman::volume { 'myvolume':
#     flags => {
#              label => 'use=test, app=wordpress',
#              }
#   }

define podman::volume (
  String $ensure  = 'present',
  Hash $flags     = {},
  String $user    = '',
  String $homedir = '',
) {
  # Convert $flags hash to command arguments
  $_flags = $flags.reduce('') |$mem, $flag| {
    "${mem} --${flag[0]} \"${flag[1]}\""
  }

  if $user != '' {
    if $homedir == '' { fail("Running as user ${user} requires 'homedir' parameter") }
    Exec {
      user        => $user,
      environment => [ "HOME=${homedir}", ],
    }
  }

  case $ensure {
    'present': {
      Exec { "podman_create_volume_${title}":
        path    => '/sbin:/usr/sbin:/bin:/usr/bin',
        command => "podman volume create ${_flags} ${title}",
        unless  => "podman volume inspect ${title}",
      }
    }
    'absent': {
      Exec { "podman_remove_volume_${title}":
        path    => '/sbin:/usr/sbin:/bin:/usr/bin',
        command => "podman volume rm ${title}",
        unless  => "test ! $(podman volume inspect ${title})"
      }
    }
    default: {
      fail('"ensure" must be "present" or "absent"')
    }
  }
}
