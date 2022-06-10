# @summary pull or remove container images
#
# @param image
#   The name of the container image to pull, which should be present in a
#   configured container registry.
#
# @param ensure
#   State of the resource must be either `present` or `absent`.
#
# @param flags
#   All flags for the 'podman image pull' command are supported, using only the
#   long form of the flag name.
#
# @param user
#   Optional user for running rootless containers.  When using this parameter,
#   the user must also be defined as a Puppet resource and must include the
#   'uid', 'gid', and 'home'
#
# @param exec_env
#   Optional array of environment variables used when the container image is
#   pulled.  Useful for defining a proxy for downloads. For example:
#   ["HTTP_PROXY=http://${proxy_fqdn}:3128", "HTTPS_PROXY=http://${proxy_fqdn}:3128"]
#
# @example
#   podman::image { 'my_container':
#     image => 'my_container:tag',
#     flags => {
#              creds => 'USERNAME:PASSWORD',
#              },
#   }
#
define podman::image (
  String $image,
  String $ensure = 'present',
  Hash $flags    = {},
  String $user   = '',
  Array $exec_env = [],
){
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
        ] + $exec_env,
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
      environment => $exec_env,
    }
  }

  case $ensure {
    'present': {
      exec { "pull_image_${title}":
        command => "podman image pull ${_flags} ${image}",
        unless  => "podman image exists ${image}",
        *       => $exec_defaults,
      }
    }
    'absent': {
      exec { "pull_image_${title}":
        command => "podman image pull ${_flags} ${image}",
        unless  => "podman rmi ${image}",
        *       => $exec_defaults,
      }
    }
    default: {
      fail('"ensure" must be "present" or "absent"')
    }
  }
}
