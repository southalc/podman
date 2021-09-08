# @summary edit container options in /etc/containers
#
# @param storage
#   A hash containing any storage options you wish to set in /etc/containers/storage.conf
#
class podman::options (
  Optional[Hash] $storage_options = $podman::storage_options,
){
  require podman::install

  if $storage_options {
    $storage_defaults = {
      'ensure' => present,
      'path' => '/etc/containers/storage.conf',
    }
    inifile::create_ini_settings($storage_options, $storage_defaults)
  }
}
