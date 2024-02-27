# @summary Generate and manage podman container quadlet definition (podman > 4.4.0)
#
# @see podman-systemd.unit.5 https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
#
# @param ensure State of the container definition.
# @param path Location to create container file in.
# @param owner Owner of container file.
# @param group Group of container file.
# @param mode Filemode of container file.
# @param daemon_reload Call `systemctl daemon-reload` to generate service file.
# @param active Make sure the container is running.
# @param unit_entry The `[Unit]` section definition.
# @param install_entry The `[Install]` section definition.
# @param service_entry The `[Service]` section definition.
# @param container_entry The `[Container]` section defintion.
#
# @example Run a CentOS Container
#   podman::manage_container{'centos.container':
#     ensure          => present,
#     unit_entry     => {
#      'Description' => 'Trivial Container that will be very lazy',
#     },
#     service_entry       => {
#       'TimeoutStartSec' => '900',
#     },
#     container_entry => {
#       'Image' => 'quay.io/centos/centos:latest',
#       'Exec'  => 'sh -c "sleep inf'
#     },
#     install_entry   => {
#       'WantedBy' => 'default.target'
#     },
#     active          => true,
#   }
#
define podman::manage_container (
  Enum['present', 'absent'] $ensure = 'present',
  Enum['/etc/containers/systemd'] $path  = '/etc/containers/systemd',
  Enum['root'] $owner = 'root',
  Enum['root'] $group = 'root',
  Stdlib::Filemode $mode = '0444',
  Boolean $daemon_reload = true,
  Optional[Boolean] $active = undef,
  Optional[Systemd::Unit::Install] $install_entry = undef,
  Optional[Systemd::Unit::Unit] $unit_entry = undef,
  Optional[Systemd::Unit::Service] $service_entry = undef,
  Optional[Podman::Quadret::Container] $container_entry = undef,
) {
  assert_type(Pattern[/[a-zA-Z\-_+]+\.container/], $name)

  include podman

  file { "${path}/${name}":
    ensure  => $ensure,
    owner   => $owner,
    group   => $group,
    mode    => $mode,
    content => epp('podman/quadlet_file.epp', {
        unit_entry      => $unit_entry,
        service_entry   => $service_entry,
        install_entry   => $install_entry,
        container_entry => $container_entry,
    }),
  }

  if $daemon_reload {
    ensure_resource('systemd::daemon_reload', $name)
    File["${path}/${name}"] ~> Systemd::Daemon_reload[$name]
  }

  if $active != undef {

    $_service = regsubst($name,'(.+)\\.container','\\1.service')

    service { $_service:
      ensure => $active,
    }

    if $ensure == 'absent' {
      if $active {
        fail("Can't ensure the container if absent and activate the service at the same time")
      }
      Service[$_service] -> File["${path}/${name}"]
    } else {
      File["${path}/${name}"] ~> Service[$_service]

      if $daemon_reload {
        Systemd::Daemon_reload[$name] ~> Service[$_service]
      }
    }
  }
}
