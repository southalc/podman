# @api private
# @summary Install podman packages
#
# @param podman_pkg
#   The name of the podman package (default 'podman')
#
# @param skopeo_pkg
#   The name of the skopeo package (default 'skopeo')
#
# @param buildah_pkg
#   The name of the buildah package (default 'buildah')
#
# @param buildah_pkg_ensure
#   The ensure value for the buildah package (default 'absent')
#
# @param podman_docker_pkg
#   The name of the podman-docker package (default 'podman-docker').  To avoid installing this optional
#   component, define it as undef (use a tilde `~` in hiera).
#
# @param podman_docker_pkg_ensure
#   The ensure value for the podman docker package (default 'installed')
#
# @param file_header
#   The name of the file header to use with managed files (default '$podman::file_header')
#
# @param manage_subuid
#   Should the class manage the system subuid/subgid files? (default '$podman::manage_subuid')
#
# @param subid
#   A hash of sub uid/gid entries for each managed user (default '$podman::subid')
#
# @param nodocker
#   The state of the '/etc/nodocker' file, either 'absent' or 'file'. (default '$podman::nodocker')
#
class podman::install (
  String $podman_pkg                                    = $podman::podman_pkg,
  String $skopeo_pkg                                    = $podman::skopeo_pkg,
  Optional[String] $buildah_pkg                         = $podman::buildah_pkg,
  Enum['absent', 'installed'] $buildah_pkg_ensure       = $podman::buildah_pkg_ensure,
  Optional[String] $podman_docker_pkg                   = $podman::podman_docker_pkg,
  Enum['absent', 'installed'] $podman_docker_pkg_ensure = $podman::podman_docker_pkg_ensure,
  String $file_header                                   = $podman::file_header,
  Boolean $manage_subuid                                = $podman::manage_subuid,
  Boolean $match_subuid_subgid                          = $podman::match_subuid_subgid,
  Hash $subid                                           = $podman::subid,
  Enum['absent', 'file'] $nodocker                      = $podman::nodocker,
){
  ensure_resource('Package', $podman_pkg, { 'ensure' => 'installed' })
  ensure_resource('Package', $skopeo_pkg, { 'ensure' => 'installed' })
  if $buildah_pkg { ensure_resource('Package', $buildah_pkg, { 'ensure' => $buildah_pkg_ensure }) }
  if $podman_docker_pkg { ensure_resource('Package', $podman_docker_pkg, { 'ensure' => $podman_docker_pkg_ensure }) }

  if $manage_subuid {
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
      content => $file_header,
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
      content => $file_header,
    }

    if $match_subuid_subgid {
      $subid.each |$name, $properties| {
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
      require    => Package[$podman_pkg],
    }
  }

  file { '/etc/containers/nodocker':
    ensure  => $nodocker,
    group   => 'root',
    owner   => 'root',
    mode    => '0644',
    require => Package[$podman_pkg],
  }
}
