# @summary Manage entries in `/etc/subuid`
#
# @param subuid Integer
#   Numerical subordinate user ID
#
# @param count Integer
#   Numerical subordinate user ID count
#
# @param order  Integer
#   Fragment order for /etc/subuid entries
#
# @example
#   podman::subuid { 'myuser':
#     subuid => 1000000
#     count  => 65535
#   }
#
define podman::subuid (
  Integer $subuid,
  Integer $count,
  Integer $order   = 10,
) {

  Concat::Fragment { "subuid_fragment_${title}":
    order   => $order,
    target  => '/etc/subuid',
    content => "${title}:${subuid}:${count}",
  }
}
