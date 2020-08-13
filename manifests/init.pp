# @summary Manage containers, pods, volumes, and images with podman without a docker daemon
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
# @param pods [Hash]
#   A hash of pods to manage using [`podman::pod`](#podmanpod)
#
# @param volumes [Hash]
#   A hash of volumes to manage using [`podman::volume`](#podmanvolume)
#
# @param images [Hash]
#   A hash of images to manage using [`podman::image`](#podmanimage)
#
# @param containers [Hash]
#   A hash of containers to manage using [`podman::container`](#podmancontainer)
#
#
# @example Basic usage
#   include podman
#
# @example A rootless Jenkins deployment using hiera
#   podman::volumes:
#     jenkins:
#       user: jenkins
#       homedir: /home/jenkins
#   podman::containers:
#     jenkins:
#       user: jenkins
#       homedir: /home/jenkins
#       image: 'docker.io/jenkins/jenkins:lts'
#       flags:
#         label:
#           - purpose=test
#         publish:
#           - '8080:8080'
#           - '50000:50000'
#         volume: 'jenkins:/var/jenkins_home'
#       service_flags:
#         timeout: '60'
#       require:
#         - Podman::Volume[jenkins]
#
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
