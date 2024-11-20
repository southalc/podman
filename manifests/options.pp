# @summary edit container options in /etc/containers
# @api private
#
class podman::options {
  require podman::install

  unless $podman::storage_options.empty {
    $storage_defaults = {
      'ensure' => present,
      'path' => '/etc/containers/storage.conf',
    }
    inifile::create_ini_settings($podman::storage_options, $storage_defaults)
  }

  unless $podman::containers_options.empty {
    $containers_defaults = {
      'ensure' => present,
      'path' => '/etc/containers/containers.conf',
    }
    inifile::create_ini_settings($podman::containers_options, $containers_defaults)
  }
}
