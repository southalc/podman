# @summary Manage entries in `/etc/subuid`
#
# @param subuid
#   Numerical subordinate user ID
#
# @param count
#   Numerical subordinate user ID count
#
# @param order
#   Sequence number for concat fragments
#
# @example
#   podman::subuid { 'namevar':
#     subuid => 1000000
#     count  => 65535
#   }
#
define podman::subuid (
  Integer $subuid,
  Integer $count,
  Integer $order  = 10,
) {
  Concat::Fragment { "subuid_fragment_${title}":
    order   => $order,
    target  => '/etc/subuid',
    content => "${title}:${subuid}:${count}",
  }
}
