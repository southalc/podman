# @summary A short summary of the purpose of this defined type.
#
# @param ensure Boolean
#   State of the resource, present or absent. Default is 'present'
#
# @param subgid Integer
#   Numerical subordinate user ID
#
# @param count Integer
#   Numerical subordinate user ID count
#
# A description of what this defined type does
#
# @example
#   podman::subgid { 'namevar':
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
