# @summary
#  Manage a podman secret. Create and remove secrets, it cannot replace.
#
# @param ensure
#  State of the resource must be either 'present' or 'absent'.
#
# @param path
#  Load secret from an existing file path
#  The secret and path parameters are mutually exclusive.
#
# @param secret
#  A secret to be stored - can be set as a Deferred function. If the secret is
#  changed the secret will **NOT** be modified. Best to set a secret version
#  as a label.
#  The secret and path parameters are mutually exclusive.
#
# @param flags
#   All flags for the 'podman secret create' command are supported as part of the
#   'flags' hash, using only the long form of the flag name.  The value for any
#   defined flag in the 'flags' hash must be entered as a string.
#   If the flags for a secret are modified the secret will be recreated.
#
# @param user
#   Optional user for running rootless containers.  When using this parameter,
#   the user must also be defined as a Puppet resource and must include the
#   'uid', 'gid', and 'home'
#
# @example Set a secret with a version from puppet directly
#   podman::secret{'db_password':
#     secret => Sensitive('NeverGuess'),
#     flags  => {
#       label => [
#         'version=20230615',
#       ]
#     }
#   }
#
# @example Set a secret from a file
#   podman::secret{'db_password':
#     path => '/etc/passwd',
#   }
#
# @example Set a secret from a deferred function call.
#   podman::secret{'ora_password':
#     secret => Sensitive(Deferred('secret_lookup',['ora_password'])),
#     flags => {
#       labels => ['version=20230615'],
#     }
#     user => 'rootless user',
#   }
#
define podman::secret (
  Enum['present','absent'] $ensure = 'present',
  Optional[Sensitive[String]] $secret = undef,
  Optional[Stdlib::Unixpath] $path = undef,
  Optional[String[1]] $user = undef,
  Hash $flags = {},
) {
  require podman::install

  # Add a puppet resource flags label for resource tracking
  $flags_base64 = base64('encode',String($flags.delete('secret')),'strict')

  # Add the default name and a custom label using the base64 encoded flags
  if 'label' in  $flags {
    $label = $flags['label'] + "puppet_resource_flags=${flags_base64}"
    $no_label = $flags.delete('label')
  } else {
    $label = "puppet_resource_flags=${flags_base64}"
    $no_label = $flags
  }

  $merged_flags = stdlib::merge({ label => $label }, $no_label )

  if $user {
    ensure_resource('podman::rootless', $user, {})
  }

  # Use the custom podman_secret resource type
  podman_secret { $title:
    ensure => $ensure,
    secret => $secret,
    path   => $path,
    flags  => $merged_flags,
    user   => $user,
  }
}
