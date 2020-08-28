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
# @param manage_subuid [Boolean]
#   Should the module manage the `/etc/subuid` and `/etc/subgid` files (default is true)
#
# @param file_header [String]
#   Optional header when `manage_subuid` is true.  Ensure you include a leading `#`.
#   Default file_header is `# FILE MANAGED BY PUPPET`
#
# @param match_subuid_subgid [Boolean]
#   Enable the `subid` parameter to manage both subuid and subgid entries with the same values.
#   This setting requires `manage_subuid` to be `true` or it will have no effect.
#   (default is true)
#
# @param subid [Hash]
#   A hash of users (or UIDs) with assigned subordinate user ID number and an count.
#   Implemented by using the `subuid` and `subgid` defined types with the same data.
#   Hash key `subuid` is the subordinate UID, and `count` is the number of subordinate UIDs
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
  Boolean $manage_subuid       = true,
  Boolean $match_subuid_subgid = true,
  String $file_header          = '# FILE MANAGED BY PUPPET',
  Hash $subid                  = {},
  Hash $pods                   = {},
  Hash $volumes                = {},
  Hash $images                 = {},
  Hash $containers             = {},
){
  include podman::install

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

  # Create resources from parameter hashes
  $pods.each |$name, $properties| { Resource['Podman::Pod'] { $name: * => $properties, } }
  $volumes.each |$name, $properties| { Resource['Podman::Volume'] { $name: * => $properties, } }
  $images.each |$name, $properties| { Resource['Podman::Image'] { $name: * => $properties, } }
  $containers.each |$name, $properties| { Resource['Podman::Container'] { $name: * => $properties, } }

}
