# private class to install podman packages

class podman::install (
  String $podman_pkg                  = $podman::podman_pkg,
  String $skopeo_pkg                  = $podman::skopeo_pkg,
  Optional[String] $podman_docker_pkg = $podman::podman_docker_pkg,
){
  ensure_resource('Package', $podman_pkg, { 'ensure' => 'installed' })
  ensure_resource('Package', $skopeo_pkg, { 'ensure' => 'installed' })
  if $podman_docker_pkg { ensure_resource('Package', $podman_docker_pkg, { 'ensure' => 'installed' }) }
}
