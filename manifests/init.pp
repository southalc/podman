# @summary Manage containers and images with podman
#
# Module installs the 'podman', 'skopeo', and optional 'podman-docker' packages,
# enabling systems to run OCI-compliant container images without the docker
# daemon.
#
# Defined types for 'pods', 'voluems', 'images', and 'containers' are all
# implemented in the base class so they they can be easily managed using
# hiera data. 

class podman (
  String $podman_pkg,
  String $skopeo_pkg,
  Optional[String] $podman_docker_pkg,
  Hash $pods                = {},
  Hash $volumes             = {},
  Hash $images              = {},
  Hash $containers          = {},
){
  include podman::install

  # Create resources from parameter hashes
  $pods.each |$name, $properties| { Resource['Podman::Pod'] { $name: * => $properties, } }
  $volumes.each |$name, $properties| { Resource['Podman::Volume'] { $name: * => $properties, } }
  $images.each |$name, $properties| { Resource['Podman::Image'] { $name: * => $properties, } }
  $containers.each |$name, $properties| { Resource['Podman::Container'] { $name: * => $properties, } }
}
