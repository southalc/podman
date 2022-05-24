# @summary Manage the podman.socket and podman-auto-update.timer service
# @api private
#
class podman::service {
  require podman::install

  $ensure = $podman::enable_api_socket ? {
    true    => 'running',
    default => 'stopped',
  }

  service { 'podman.socket':
    ensure => $ensure,
    enable => $podman::enable_api_socket,
  }

  service { 'podman-auto-update.timer':
    enable => $podman::enable_autoupdate_timer,
  }

}
