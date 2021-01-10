# @api private
# @summary Install podman packages
#
# @param podman_pkg
#   The name of the podman package (default 'podman')
#
# @param skopeo_pkg
#   The name of the skopeo package (default 'skopeo')
#
# @param podman_docker_pkg
#   The name of the podman-docker package (default 'podman-docker')
#
class podman::install (
  String $podman_pkg                  = $podman::podman_pkg,
  String $skopeo_pkg                  = $podman::skopeo_pkg,
  Optional[String] $podman_docker_pkg = $podman::podman_docker_pkg,
){
  ensure_resource('Package', $podman_pkg, { 'ensure' => 'installed' })
  ensure_resource('Package', $skopeo_pkg, { 'ensure' => 'installed' })
  if $podman_docker_pkg { ensure_resource('Package', $podman_docker_pkg, { 'ensure' => 'installed' }) }

  if $podman::manage_subuid {
    Concat { '/etc/subuid':
      owner          => 'root',
      group          => 'root',
      mode           => '0644',
      order          => 'alpha',
      ensure_newline => true,
    }

    concat_fragment { 'subuid_header':
      target  => '/etc/subuid',
      order   => 1,
      content => $podman::file_header,
    }

    Concat { '/etc/subgid':
      owner          => 'root',
      group          => 'root',
      mode           => '0644',
      order          => 'alpha',
      ensure_newline => true,
    }

    concat_fragment { 'subgid_header':
      target  => '/etc/subgid',
      order   => 1,
      content => $podman::file_header,
    }

    if $podman::match_subuid_subgid {
      $podman::subid.each |$name, $properties| {
        Resource['Podman::Subuid'] { $name: * => $properties }
        $subgid = { subgid => $properties['subuid'], count => $properties['count'] }
        Resource['Podman::Subgid'] { $name: * => $subgid }
      }
    }
  }

  if $::selinux or $facts['os']['selinux']['enabled'] {
    selboolean { 'container_manage_cgroup':
      persistent => true,
      value      => on,
    }
  }

  file { '/etc/containers/nodocker':
    ensure  => $podman::nodocker,
    group   => 'root',
    owner   => 'root',
    mode    => '0644',
    require => Package[$podman_pkg],
  }
}
