# @summary pull container images
#
# All flags for the 'podman image pull' command are supported, using only the
# long form of the flag name.
#
# @example
#   podman::image { 'my_container':
#     image => 'my_container:tag',
#     flags => {
#              creds => 'USERNAME:PASSWORD',
#              },
#   }

define podman::image (
  String $image,
  String $ensure  = 'present',
  Hash $flags     = {},
  String $user    = '',
  String $homedir = '',
){
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
      Exec { "pull_image_${title}":
        path    => '/sbin:/usr/sbin:/bin:/usr/bin',
        command => "podman image pull ${_flags} ${image}",
        unless  => "podman image exists ${image}",
      }
    }
    'absent': {
      Exec { "pull_image_${title}":
        path    => '/sbin:/usr/sbin:/bin:/usr/bin',
        command => "podman image pull ${_flags} ${image}",
        unless  => "podman rmi ${image}",
      }
    }
    default: {
      fail('"ensure" must be "present" or "absent"')
    }
  }
}
