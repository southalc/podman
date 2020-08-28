# @summary Manage entries in `/etc/subuid`
#
# @param ensure Boolean
#   State of the resource, present or absent. Default is 'present'
#
# @param subuid Integer
#   Numerical subordinate user ID
#
# @param count Integer
#   Numerical subordinate user ID count
#
# A description of what this defined type does
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
  Integer $order                    = 10,
) {

  Concat::Fragment { "subuid_fragment_${title}":
    order   => $order,
    target  => '/etc/subuid',
    content => "${title}:${subuid}:${count}",
  }
}
