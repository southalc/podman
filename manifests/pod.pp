# @summary Create a podman pod with defined flags
#
# @param ensure
#   State of the resource, which must be either 'present' or 'absent'.
#
# @param flags
#   All flags for the 'podman pod create' command are supported, using only the
#   long form of the flag name.  The resource name (namevar) will be used as the
#   pod name unless the 'name' flag is included in the hash of flags.
#
# @param user
#   Optional user for running rootless containers.  When using this parameter,
#   the user must also be defined as a Puppet resource and must include the
#   'uid', 'gid', and 'home'
#
# @example
#   podman::pod { 'mypod':
#     flags => {
#              label => 'use=test, app=wordpress',
#              }
#   }
#
define podman::pod (
  Enum['present', 'absent'] $ensure = 'present',
  Hash                      $flags  = {},
  Optional[String]          $user   = undef,
) {
  require podman::install

  # The resource name will be the pod name by default
  $pod_name = $title
  $name_flags = merge({ name => $title }, $flags )

  # Convert $flags hash to command arguments
  $_flags = $name_flags.reduce('') |$mem, $flag| {
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

  if $user != undef and $user != '' {
    ensure_resource('podman::rootless', $user, {})

    # Set execution environment for the rootless user
    $exec_defaults = {
      cwd         => User[$user]['home'],
      user        => $user,
      require     => [Podman::Rootless[$user]],
      environment => [
        "HOME=${User[$user]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$user]['uid']}",
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${User[$user]['uid']}/bus",
      ],
    }
  } else {
    $exec_defaults = {}
  }

  case $ensure {
    'present': {
      exec { "create_pod_${pod_name}":
        command  => "podman pod create ${_flags}",
        unless   => "podman pod exists ${pod_name}",
        path     => '/sbin:/usr/sbin:/bin:/usr/bin',
        provider => 'shell',
        *        => $exec_defaults,
      }
    }
    default: {
      exec { "remove_pod_${pod_name}":
        command  => "podman pod rm ${pod_name}",
        unless   => "podman pod exists ${pod_name}; test $? -eq 1",
        path     => '/sbin:/usr/sbin:/bin:/usr/bin',
        provider => 'shell',
        *        => $exec_defaults,
      }
    }
  }
}
