# @summary manage podman quadlets
#
# @param ensure
#   Valid values are 'present' or 'absent'
#
# @param user
#   A username for running rootless containers.  The user must also be defined as
#   a puppet resource that includes at least 'uid', 'gid', and 'home' attributes.
#   The default value is "root" and results in root containers and resources.
#
# @param quadlet_type
#   Must be one of the supported quadlet types: "container", "volume", "network",
#   "build", "pod", or "kube".  Default is "container"
#
# @param settings
#   A hash that represents the systemd unit file that will be managed for the podman
#   quadlet.  No sanity checking is done on this hash, so invalid values can result
#   in a service that fails to start, but this also allows full configuration of any
#   service or container setting now and in the future without needed to go back
#   and update the module.
#
# @param defaults A hash of values that's merged with settings to simplify module
#   usage.  This allows running a container with nothing but an image defined.
#
# @example
#   podman::quadlet { 'jenkins':
#     user     => 'jenkins',
#     settings => {
#       Unit => {
#         Description => "Jenkins container",
#       },
#       Container => {
#         Image       => 'docker.io/jenkins/jenkins:latest',
#         PublishPort => '8080:8080',
#         PublishPort => '50000:50000',
#         Volume      => 'jenkins:/var/jenkins_home',
#       },
#       Service => {
#         TimeoutStartSec => '180',
#       },
#     },
#   }
#
define podman::quadlet (
  Enum['present', 'absent'] $ensure = 'present',
  Enum['container',
    'volume',
    'network',
    'build',
    'pod',
    'kube'
  ] $quadlet_type                   = 'container',
  String $user                      = 'root',
  Hash $defaults                    = {}, # Values in module hiera
  Hash $settings                    = {},
) {
  $podman_version = fact('podman.version')

  if $podman_version and versioncmp($podman_version, '4.4', true) >= 0 {
    require podman::install

    $service_suffix = $quadlet_type ? {
      'volume'  => '-volume',
      'network' => '-network',
      'pod'     => '-pod',
      default   => '',
    }
    $service = "${name}${service_suffix}"

    # A rootless container will run as the defined user
    if $user == 'root' {
      $quadlet_file = "/etc/containers/systemd/${title}.${quadlet_type}"
      ensure_resource('Systemd::Daemon_reload', 'podman', {})
      $notify_systemd = Systemd::Daemon_reload['podman']
      $requires = []
    } else {
      $quadlet_file = "/etc/containers/systemd/users/${User[$user]['uid']}/${title}.${quadlet_type}"
      ensure_resource('podman::rootless', $user, {})
      $requires = [Podman::Rootless[$user]]
      ensure_resource('Systemd::Daemon_reload', "podman_rootless_${user}", { user => $user })
      $notify_systemd = Systemd::Daemon_reload["podman_rootless_${user}"]
    }

    $hash2ini_options = {
      key_val_separator => ' = ',
      use_quotes        => false,
    }

    file { $quadlet_file:
      ensure  => $ensure,
      content => hash2ini(stdlib::merge($defaults, $settings), $hash2ini_options),
      notify  => $notify_systemd,
      require => $requires,
    }

    if $user == 'root' {
      if $ensure == 'absent' {
        service { $service:
          ensure => stopped,
          notify => File[$quadlet_file],
        }
      } else {
        service { $service:
          ensure    => running,
          require   => $notify_systemd,
          subscribe => File[$quadlet_file],
        }
      }
    } else {
      if $ensure == 'absent' {
        systemd::user_service { $service:
          ensure => false,
          enable => false,
          user   => $user,
          unit   => "${service}.service",
          notify => File[$quadlet_file],
        }
      } else {
        systemd::user_service { $service:
          ensure    => true,
          enable    => true,
          user      => $user,
          unit      => "${service}.service",
          require   => $notify_systemd,
          subscribe => File[$quadlet_file],
        }
      }
    }
  } else {
    notify { "quadlet_${title}":
      message => "This version of podman (${podman_version}) does not support quadlets.",
    }
  }
}
