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
#   See the "data/common.yaml" file for default values.
#
# @param service_ensure
#   The desired state of the systemd service. Valid values are 'running' or 'stopped'.
#   Default is 'running'.
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
#         PublishPort => [
#           '5000:5000',
#           '8080:8080',
#         ],
#         Volume      => 'jenkins:/var/jenkins_home',
#       },
#       Service => {
#         TimeoutStartSec => '300',
#       },
#     },
#   }
#
# @example Timer-controlled service
#   podman::quadlet { 'backup-job':
#     service_ensure => 'stopped',
#     settings => {
#       Unit => {
#         Description => "Backup job container",
#       },
#       Container => {
#         Image => 'backup:latest',
#       },
#       Service => {
#         Type => 'oneshot',
#       },
#       Install => {
#         WantedBy => [],
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
  Enum['running', 'stopped'] $service_ensure = 'running',
) {
  $podman_supports_quadlets = case $facts['os']['family'] {
    'RedHat': {
      case $facts['os']['name'] {
        'Fedora': { true }
        default: {
          versioncmp($facts['os']['release']['major'], '8') >= 0
        }
      }
    }
    'Debian': {
      case $facts['os']['name'] {
        'Ubuntu': {
          versioncmp($facts['os']['release']['full'], '24.04') >= 0
        }
        'Debian': {
          versioncmp($facts['os']['release']['major'], '13') >= 0
        }
        default: { false }
      }
    }
    'Archlinux': { true }
    default: { false }
  }

  if $podman_supports_quadlets {
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
      ensure_resource('Systemd::Daemon_reload', $title, {})
      $notify_systemd = Systemd::Daemon_reload[$title]
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
          ensure    => $service_ensure,
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
        $user_service_ensure = $service_ensure ? {
          'running' => true,
          'stopped' => false,
        }

        systemd::user_service { $service:
          ensure    => $user_service_ensure,
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
      message => "Quadlets are not supported on ${facts['os']['name']} ${facts['os']['release']['full']}. Supported: Fedora (all), EL 8+, Ubuntu 24.04+, Debian 13+, Archlinux.",
    }
  }
}
