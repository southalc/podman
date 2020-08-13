# @summary Create a podman pod with defined flags
#
# @param ensure [String]
#   State of the resource.  Valid values are 'present' or 'absent'. (present)
#
# @param flags [Hash]
#   All flags for the 'podman pod create' command are supported, using only the
#   long form of the flag name.  The resource name (namevar) will be used as the
#   pod name unless the 'name' flag is included in the hash of flags.
#
# @param user String
#   Optional user for running rootless containers
#
# @param homedir String
#   The `homedir` parameter is required when `user` is defined.  Defining it
#   this way avoids using an external fact to lookup the home directory of
#   all users.
#
#
# @example
#   podman::pod { 'mypod':
#     flags => {
#              label => 'use=test, app=wordpress',
#              }
#   }
#
define podman::pod (
  String $ensure = 'present',
  Hash $flags    = {},
  String $user    = '',
  String $homedir = '',
) {
  # The resource name will be the pod name by default
  $name_flags = merge({ name => $title }, $flags )
  $pod_name = $name_flags['name']

  # Convert $flags hash to command arguments
  $_flags = $name_flags.reduce('') |$mem, $flag| {
    "${mem} --${flag[0]} \"${flag[1]}\""
  }

  if $user != '' {
    if $homedir == '' { fail("Running as user ${user} requires 'homedir' parameter") }
    Exec {
      path    => '/sbin:/usr/sbin:/bin:/usr/bin',
      user        => $user,
      environment => [ "HOME=${homedir}", ],
    }
  } else {
    Exec { path => '/sbin:/usr/sbin:/bin:/usr/bin', }
  }

  case $ensure {
    'present': {
      Exec { "create_pod_${pod_name}":
        command => "podman pod create ${_flags}",
        unless  => "podman pod exists ${pod_name}",
      }
    }
    'absent': {
      Exec { "remove_pod_${pod_name}":
        command => "podman pod rm ${pod_name}",
        unless  => "podman pod exists ${pod_name}; test $? -eq 1",
      }
    }
    default: {
        fail('"ensure" must be "present" or "absent"')
    }
  }
}
