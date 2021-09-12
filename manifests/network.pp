# @summary Create a podman network with defined flags
#
# @param ensure
#   State of the resource must be either 'present' or 'absent'.
#
# @param disable_dns
#   Disables the DNS plugin for this network which if enabled, can perform container
#   to container name resolution.
#
# @param driver
#   Driver to manage the network.
#
# @param opts
#   A list of driver specific options.
#
# @param gateway
#   Define the gateway for the network. Must also provide the subnet.
#
# @param internal
#   Restrict external access of this network.
#
# @param ip_range
#   Allocate container IP from a range. The range must be a complete subnet and in
#   CIDR notation.
#
# @param label
#   A hash of metadata labels to set on the network.
#
# @param subnet
#   The subnet in CIDR notation
#
# @param ipv6
#   Enable IPv6 (dual-stack) networking.
#
# @example
#   podman::network { 'mnetwork':
#     driver   => 'bridge',
#     internal => true,
#   }
#
define podman::network (
  Enum['present', 'absent'] $ensure = 'present',
  Enum['bridge', 'macvlan'] $driver = 'bridge',
  Boolean $disable_dns = false,
  Array[String] $opts = [],
  Optional[String] $gateway = undef,
  Boolean $internal = false,
  Optional[String] $ip_range = undef,
  Hash[String,String] $labels = {},
  Optional[String] $subnet = undef,
  Boolean $ipv6 = false,
) {
  require podman::install

  $_disable_dns = $disable_dns ? {
    true    => '--disable-dns',
    default => '',
  }

  # Convert opts list to command arguments
  $_opts = $opts.reduce('') |$mem, $opt| {
    "${mem} --flag ${opt}"
  }

  # Convert $labels hash to command arguments
  $_labels = $labels.reduce('') |$mem, $label| {
    if $label[1] =~ String {
      "${mem} --label ${label[0]} '${label[1]}'"
    } else {
      $dup = $label[1].reduce('') |$mem2, $value| {
        "${mem2} --${label[0]} '${value}'"
      }
      "${mem} ${dup}"
    }
  }

  $_gateway = $gateway ? {
    undef   => '',
    default => "--gateway ${gateway}",
  }

  $_internal = $internal ? {
    true    => '--internal',
    default => '',
  }

  $_ip_range = $ip_range ? {
    undef   => '',
    default => "--ip-range ${ip_range}"
  }

  $_subnet = $subnet ? {
    undef   => '',
    default => "--subnet ${subnet}",
  }

  $_ipv6 = $ipv6 ? {
    true    => '--ipv6',
    default => '',
  }

  case $ensure {
    'present': {
      exec { "podman_create_network_${title}":
        command => @("END"/L),
                   podman network create ${title} --driver ${driver} ${_opts} \
                    ${_gateway} ${_internal} ${_ip_range} ${_labels} ${_subnet} ${_ipv6}"
                   |END
        unless  => "podman network exists ${title}",
        path    => ['/usr/bin', '/bin']
      }
    }
    'absent': {
      exec { "podman_remove_volume_${title}":
        command => "podman network rm ${title}",
        onlyif  => "podman network exists ${title}",
        path    => ['/usr/bin', '/bin']
      }
    }
    default: {
      fail('"ensure" must be "present" or "absent"')
    }
  }
}

