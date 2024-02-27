# @summary Generate and manage podman quadlet definitions (podman > 4.4.0)
#
# @see podman-systemd.unit.5 https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
#
# @param quadlet of the quadlet file this is the namevar.
# @param ensure State of the container definition.
# @param user User running the container
# @param mode Filemode of container file.
# @param active Make sure the container is running.
# @param unit_entry The `[Unit]` section definition.
# @param install_entry The `[Install]` section definition.
# @param service_entry The `[Service]` section definition.
# @param container_entry The `[Container]` section defintion.
# @param pod_entry The `[Pod]` section defintion.
# @param volume_entry The `[Volume]` section defintion.
#
# @example Run a CentOS Container
#   quadlet::quadlet{'centos.container':
#     ensure          => present,
#     unit_entry     => {
#      'Description' => 'Trivial Container that will be very lazy',
#     },
#     service_entry       => {
#       'TimeoutStartSec' => '900',
#     },
#     container_entry => {
#       'Image' => 'quay.io/centos/centos:latest',
#       'Exec'  => 'sh -c "sleep inf"'
#     },
#     install_entry   => {
#       'WantedBy' => 'default.target'
#     },
#     active          => true,
#   }
#
define podman::quadlet (
  Enum['present', 'absent'] $ensure = 'present',
  Podman::Quadlet_name $quadlet = $title,
  String[1] $user = 'root',
  Stdlib::Filemode $mode = '0444',
  Optional[Boolean] $active = undef,
  Optional[Systemd::Unit::Install] $install_entry = undef,
  Optional[Systemd::Unit::Unit] $unit_entry = undef,
  Optional[Systemd::Unit::Service] $service_entry = undef,
  Optional[Podman::Unit::Container] $container_entry = undef,
  Optional[Podman::Unit::Volume] $volume_entry = undef,
  Optional[Podman::Unit::Pod] $pod_entry = undef,
) {
  $_split = $quadlet.split('[.]')
  $_name = $_split[0]
  $_type = $_split[1]
  # Validate the input and find the service name.
  case $_type {
    'container': {
      if $volume_entry or $pod_entry {
        fail('A volume_entry or pod_entry makes no sense on a container quadlet')
      }
      $_service = "${_name}.service"
    }
    'volume': {
      if $container_entry or $pod_entry {
        fail('A container_entry or pod_entry makes no sense on a volume quadlet')
      }
      $_service = "${_name}-volume.service"
    }
    'pod': {
      if $container_entry or $volume_entry {
        fail('A container_entry or volume_entry makes no sense on a pod quadlet')
      }
      $_service = "${_name}-pod.service"
    }
    default: {
      fail('Should never be here due to typing on quadlet')
    }
  }

  include podman

  # Determine path
  if $user == 'root' {
    $_path = '/etc/containers/systemd'
    $_group = root
  } else {
    $_path = "${User[$user]['home']}/.config/containers/systemd"
    $_group = User[$user]['gid']
    ensure_resource('podman::rootless', $user, {})
  }

  file { "${_path}/${quadlet}":
    ensure  => $ensure,
    owner   => $user,
    group   => $_group,
    mode    => $mode,
    content => epp('podman/quadlet_file.epp', {
        'unit_entry'      => $unit_entry,
        'service_entry'   => $service_entry,
        'install_entry'   => $install_entry,
        'container_entry' => $container_entry,
        'volume_entry'    => $volume_entry,
        'pod_entry'       => $pod_entry,
    }),
  }

  if $user == 'root' {
    ensure_resource('systemd::daemon_reload', $quadlet)
    File["${_path}/${quadlet}"] ~> Systemd::Daemon_reload[$quadlet]
  } else {
    File["${_path}/${quadlet}"] ~> Exec["daemon-reload-${user}"]
    File["${_path}/${quadlet}"] -> Exec["start_${user}.slice"]
  }

  if $active != undef {
    if $user == 'root' {
      service { $_service:
        ensure => $active,
      }

      if $ensure == 'absent' {
        Service[$_service] -> File["${_path}/${quadlet}"]
        File["${_path}/${quadlet}"] ~> Systemd::Daemon_reload[$quadlet]
      } else {
        File["${_path}/${quadlet}"] ~> Service[$_service]
        Systemd::Daemon_reload[$quadlet] ~> Service[$_service]
      }
    } else {
      $_systemctl_user = ['systemd-run','--pipe', '--wait', '--user','--machine',"${user}@.host", 'systemctl','--user']
      if $active == true {
        exec { "start-${quadlet}-${user}":
          command => $_systemctl_user + ['start', $_service],
          unless  => [$_systemctl_user + ['is-active', $_service]],
          path    => $facts['path'],
        }
        exec { "reload-${quadlet}-${user}":
          command     => $_systemctl_user + ['try-reload-or-restart', $_service],
          refreshonly => true,
          path        => $facts['path'],
          before      => Exec["start-${quadlet}-${user}"],
        }
        File["${_path}/${quadlet}"] ~> Exec["reload-${quadlet}-${user}"]
        Exec["daemon-reload-${user}"] ~> Exec["reload-${quadlet}-${user}"]
      } else {
        exec { "stop-${quadlet}-${user}":
          command => $_systemctl_user + ['stop', $_service],
          onlyif  => [$_systemctl_user + ['is-active', $_service]],
          path    => $facts['path'],
        }
      }
    }
  }
}
