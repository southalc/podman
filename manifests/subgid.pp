# @summary Define an entry in the `/etc/subgid` file.
#
# @param subgid
#   Numerical subordinate group ID
#
# @param count
#   Numerical subordinate group ID count
#
# @param order
#   Sequence number for concat fragments#
#
# @example
#   podman::subgid { 'myuser':
#     subgid => 1000000
#     count  => 65535
#   }
#
define podman::subgid (
  Integer $subgid,
  Integer $count,
  Integer $order = 10,
) {

  Concat::Fragment { "subgid_fragment_${title}":
    order   => $order,
    target  => '/etc/subgid',
    content => "${title}:${subgid}:${count}",
  }
}
