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

  # Do not encode and store the secret
  $flags_base64 = base64('encode',String($flags.delete('secret')),'strict')

  # Add the default name and a custom label using the base64 encoded flags
  if 'label' in  $flags {
    $label = $flags['label'] + "puppet_resource_flags=${flags_base64}"
    $no_label = $flags.delete('label')
  } else {
    $label = "puppet_resource_flags=${flags_base64}"
    $no_label = $flags
  }

  # If a secret name is not set, use the Puppet resource name
  $merged_flags = stdlib::merge({ label => $label }, $no_label )

  # Convert $flags hash to command arguments
  $_flags = $merged_flags.reduce('') |$mem, $flag| {
    if $flag[1] =~ String {
      "${mem} --${flag[0]} '${flag[1]}'"
    } elsif $flag[1] =~ Undef {
      "${mem} --${flag[0]}"
    } else {
      $dup = $flag[1].reduce('') |$mem2, $value| {
        "${mem2} --${flag[0]} '${value}'"
      }
      "${mem} ${dup}"
    }
  }

  if $user {
    ensure_resource('podman::rootless', $user, {})

    # Set execution environment for the rootless user
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
      environment => [
        "HOME=${User[$user]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$user]['uid']}",
      ],
      cwd         => User[$user]['home'],
      provider    => 'shell',
      user        => $user,
      require     => Podman::Rootless[$user],
    }
  } else {
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
      provider    => 'shell',
    }
  }

  if $secret and $path {
    fail('Only one of the parameters path or secret to podman::secret must be set')
  } elsif $secret {
    $_command = Sensitive(stdlib::deferrable_epp('podman/set_secret_from_stdin.epp', {
          'secret' => $secret ,
          'title'  => $title,
          'flags'  => $_flags,
    }))
  } elsif $path {
    $_command = "podman secret create${_flags} ${title} ${path}"
  } else {
    fail('One of the parameters path or secret to podman::secret must be set')
  }

  case $ensure {
    'present': {
      Exec { "create_secret_${title}":
        command => $_command,
        unless  => "test \"$(podman secret inspect ${title}  --format ''{{.Spec.Labels.puppet_resource_flags}}'')\" = \"${flags_base64}\"",
        *       => $exec_defaults,
      }
    }
    default: {
      Exec { "create_secret_${title}":
        command => $_command,
        unless  => "podman secret rm ${title}",
        onlyif  => "podman secret inspect ${title}",
        *       => $exec_defaults,
      }
    }
  }
}
