# @api private
# @summary Manage the podman.socket service
#
# @param enable_api_socket `enable` attribute for the `podman.socket` service
#
# @param ensure `ensure` attribute for the `podman.socket` service
#
class podman::service (
  Boolean $enable_api_socket  = $podman::enable_api_socket,
  Optional[String[1]] $ensure = $enable_api_socket ? {
    true    => 'running',
    default => 'stopped',
  },
) {
  service { 'podman.socket':
    ensure => $ensure,
    enable => $enable_api_socket,
  }
}
