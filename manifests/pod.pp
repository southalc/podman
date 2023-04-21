# @summary Create a podman pod with defined flags and containers.
#
# @param ensure
#   State of the resource, which must be either 'present' or 'absent'.
#
# @param flags
#   All flags for the 'podman pod create' command are supported, using only the
#   long form of the flag name.  The resource name (namevar) will be used as the
#   pod name unless the 'name' flag is included in the hash of flags.
#
# @param user
#   Optional user for running rootless containers.  When using this parameter,
#   the user must also be defined as a Puppet resource and must include the
#   'uid', 'gid', and 'home'
#
# @param enable
#   Start/enable the systemd service unit for the pod. Does not apply if no
#   containers are declared for the pod because the systemd service unit will
#   not be created without containers.
#
# @param containers
#   Hash of containers to add to the pod.
#
# @example
#   podman::pod { 'mypod':
#     flags => {
#              label   => 'use=test, app=wordpress',
#              publish => '8443:443',
#     },
#     containers => {
#       wordpress => {
#         image => 'wordpress:php8.2-fpm-alpine',
#       },
#       haproxy => {
#         image => 'haproxy:latest',
#       },
#     },
#   }
#
# @note If the flags or container hashes change, the entire pod will be redeployed.
#
define podman::pod (
  Enum['present', 'absent'] $ensure = 'present',
  Hash $flags                       = {},
  String $user                      = '',
  Boolean $enable                   = true,
  Hash $containers                  = {},
) {
  require podman::install

  # Add a label that is the sha256 of the flags and containers hashes
  # This will be used to redeploy the pod if the flags or containers change
  $pod_sha256 = sha256(inline_template('<%= @flags.to_s + @containers.to_s %>'))
  if has_key($flags, 'label') {
    $label = [] + $flags['label'] + "puppet_resource_sha256=${pod_sha256}"
    $no_label = $flags.delete('label')
  } else {
    $label = "puppet_resource_sha256=${pod_sha256}"
    $no_label = $flags
  }

  # The resource name will be the pod name by default
  $merged_flags = { name => $title, label => $label} + $no_label
  $pod_name = $merged_flags['name']
  $service_unit = "pod-${pod_name}.service"

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

  if $user != '' {
    ensure_resource('podman::rootless', $user, {})
    $systemctl = 'systemctl --user '
    $service_unit_dir = "${User[$user]['home']}/.config/systemd/user"
    $handle = "${user}-${pod_name}"

    # Set execution environment for the rootless user
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
      environment => [
        "HOME=${User[$user]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$user]['uid']}",
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${User[$user]['uid']}/bus",
      ],
      cwd         => User[$user]['home'],
      provider    => 'shell',
      user        => $user,
    }
    $requires = [
      Podman::Rootless[$user],
      Service['podman systemd-logind'],
    ]

    # Reload systemd when service files are updated
    ensure_resource('Exec', "podman_systemd_${user}_reload", {
        path        => '/sbin:/usr/sbin:/bin:/usr/bin',
        command     => "${systemctl} daemon-reload",
        refreshonly => true,
        environment => [
          "HOME=${User[$user]['home']}",
          "XDG_RUNTIME_DIR=/run/user/${User[$user]['uid']}",
        ],
        cwd         => User[$user]['home'],
        provider    => 'shell',
        user        => $user,
      }
    )
    $podman_systemd_reload = "podman_systemd_${user}_reload"

  } else {
    $systemctl = 'systemctl '
    $service_unit_dir = '/etc/systemd/system/'
    $handle = $pod_name

    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
      provider    => 'shell',
    }

    # Reload systemd when service files are updated
    ensure_resource('Exec', 'podman_systemd_reload', {
        path        => '/sbin:/usr/sbin:/bin:/usr/bin',
        command     => "${systemctl} daemon-reload",
        refreshonly => true,
      }
    )
    $requires = []
    $podman_systemd_reload = 'podman_systemd_reload'
  }

  if $ensure == 'present' {
    # Detect changes to the defined podman sha256 and re-deploy if needed
    exec { "verify_pod_sha256_${handle}":
      command => 'true',
      unless  => @("END"/$L),
        if podman pod exists ${pod_name}; then
          saved_sha256=\$(podman pod inspect ${pod_name} --format '{{.Labels.puppet_resource_sha256}}')
          test "\${saved_sha256}" = "${pod_sha256}"
        fi
        |END
      require => $requires,
      notify  => [
        Exec["service_stop_pod_${handle}"],
        Exec["service_remove_pod_${handle}"],
        Exec["podman_remove_pod_${handle}"],
      ],
      *       => $exec_defaults,
    }

    # Stop pod service unit if pod changed
    exec { "service_stop_pod_${handle}":
      command     => "${systemctl} disable --now ${service_unit}",
      onlyif      => @("END"/L),
        ${systemctl} is-active ${service_unit} || \
        ${systemctl} is-enabled ${service_unit}
        |END
      refreshonly => true,
      *           => $exec_defaults,
    }

    # Remove pod service units if pod changed
    exec { "service_remove_pod_${handle}":
      command     => "rm -f ${service_unit} container-${pod_name}-*.service",
      refreshonly => true,
      require     => Exec["service_stop_pod_${handle}"],
      before      => Exec["create_pod_${handle}"],
      *           => $exec_defaults + {cwd => $service_unit_dir},
    }

    # Remove pod if pod changed
    exec { "podman_remove_pod_${handle}":
      command     => "podman pod rm --force ${pod_name}",
      refreshonly => true,
      require     => Exec["service_stop_pod_${handle}"],
      before      => Exec["create_pod_${handle}"],
      *           => $exec_defaults,
    }

    # Create pod
    exec { "create_pod_${handle}":
      command => "podman pod create ${_flags}",
      unless  => "podman pod exists ${pod_name}",
      *       => $exec_defaults,
    }

    # Set up systemd service units if pod has active containers
    unless $containers.empty() {
      # Declare the containers
      $containers.each |$container, $params| {
        podman::container { "${pod_name}-${container}":
          user    => $user,
          pod     => $pod_name,
          require => Exec["create_pod_${handle}"],
          notify  => Exec["podman_generate_service_${handle}"],
          *       => $params
        }
      }

      # Generate service units
      exec { "podman_generate_service_${handle}":
        command     => "podman generate systemd -f -n ${pod_name}",
        refreshonly => true,
        notify      => Exec[$podman_systemd_reload],
        *           => $exec_defaults + {cwd => $service_unit_dir},
      }

      # Start/stop systemd service units.
      if $enable {
        exec { "service_pod_${handle}":
          command => "${systemctl} enable --now ${service_unit}",
          unless  => @("END"/L),
            ${systemctl} is-active ${service_unit} && \
            ${systemctl} is-enabled ${service_unit}
            |END
          require => Exec[$podman_systemd_reload],
          *       => $exec_defaults,
        }
      } else {
        exec { "service_pod_${handle}":
          command => "${systemctl} disable --now ${service_unit}",
          onlyif  => @("END"/L),
            ${systemctl} is-active ${service_unit} || \
            ${systemctl} is-enabled ${service_unit}
            |END
          require => Exec[$podman_systemd_reload],
          *       => $exec_defaults,
        }
      }
    }
  } else {
    # Ensure pod is absent

    # Stop pod service unit
    exec { "service_stop_pod_${handle}":
        command => "${systemctl} disable --now ${service_unit}",
        onlyif  => @("END"/L),
          ${systemctl} is-active ${service_unit} || \
          ${systemctl} is-enabled ${service_unit}
          |END
        notify  => Exec["service_remove_pod_${handle}"],
        *       => $exec_defaults,
      }

    # Remove pod service units
    exec { "service_remove_pod_${handle}":
      command     => "rm -f ${service_unit} container-${pod_name}-*.service",
      refreshonly => true,
      notify      => Exec[$podman_systemd_reload],
      *           => $exec_defaults + {cwd => $service_unit_dir},
    }

    # Remove pod
    exec { "podman_remove_pod_${handle}":
      command => "podman pod rm --force ${pod_name}",
      onlyif  => "podman pod exists ${pod_name}",
      require => Exec["service_stop_pod_${handle}"],
      *       => $exec_defaults,
    }
  }
}
