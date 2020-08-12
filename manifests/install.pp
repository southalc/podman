# @api private
# @summary Install podman packages
#
# === Parameters ===
#
# @param podman_pkg [String]
#   The name of the podman package (default 'podman')
# 
# @param skopeo_pkg [String]
#   The name of the skopeo package (default 'skopeo')
#
# @param podman_docker_pkg Optional[String]
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
}
