# @summary Install podman packages
# @api private
#
class podman::install {
  ensure_resource('Package', $podman::podman_pkg, { 'ensure' => 'installed' })
  ensure_resource('Package', $podman::skopeo_pkg, { 'ensure' => 'installed' })
  ensure_resource('Package', $podman::buildah_pkg, { 'ensure' => $podman::buildah_pkg_ensure })
  ensure_resource('Package', $podman::podman_docker_pkg, { 'ensure' => $podman::podman_docker_pkg_ensure })
  ensure_resource('Package', $podman::compose_pkg, { 'ensure' => $podman::compose_pkg_ensure })
  ensure_resource('Package', $podman::machinectl_pkg, { 'ensure' => $podman::machinectl_pkg_ensure })

  if $podman::manage_subuid {
    concat { ['/etc/subuid', '/etc/subgid']:
      owner          => 'root',
      group          => 'root',
      mode           => '0644',
      order          => 'alpha',
      ensure_newline => true,
    }

    concat_fragment {
      default:
        order   => 1,
        content => $podman::file_header,
      ;
      'subuid_header':
        target  => '/etc/subuid',
      ;
      'subgid_header':
        target  => '/etc/subgid',
      ;
    }

    if $podman::match_subuid_subgid {
      $podman::subid.each |$name, $properties| {
        Resource['Podman::Subuid'] { $name: * => $properties }
        $subgid = { subgid => $properties['subuid'], count => $properties['count'] }
        Resource['Podman::Subgid'] { $name: * => $subgid }
      }
    }
  }

  if $::selinux == true or $facts['os']['selinux']['enabled'] == true {
    selboolean { 'container_manage_cgroup':
      persistent => true,
      value      => on,
      require    => Package[$podman::podman_pkg],
    }
  }

  file { '/etc/containers/nodocker':
    ensure  => $podman::nodocker,
    group   => 'root',
    owner   => 'root',
    mode    => '0644',
    require => Package[$podman::podman_pkg],
  }
}
