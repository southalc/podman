# @summary manage podman container and register as a systemd service
#
# @param image
#   Container registry source of the image being deployed.  Required when
#   `ensure` is `present` but optional when `ensure` is set to `absent`.
#
# @param user
#   Optional user for running rootless containers.  For rootless containers,
#   the user must also be defined as a puppet resource that includes at least
#   'uid', 'gid', and 'home' attributes.
#
# @param flags
#   All flags for the 'podman container create' command are supported via the
#   'flags' hash parameter, using only the long form of the flag name.  The
#   container name will be set as the resource name (namevar) unless the 'name'
#   flag is included in the flags hash.  If the flags for a container resource
#   are modified the container will be destroyed and re-deployed during the
#   next puppet run.  This is achieved by storing the complete set of flags as
#   a base64 encoded string in a container label named `puppet_resource_flags`
#   so it can be compared with the assigned resource state.
#   Flags that can be used more than once should be expressed as an array.  For
#   flags which take no arguments, set the hash value to be undef. In the
#   YAML representation you can use `~` or `null` as the value.
#
# @param service_flags
#   When a container is created, a systemd unit file for the container service
#   is generated using the 'podman generate systemd' command.  All flags for the
#   command are supported using the 'service_flags" hash parameter, again using
#   only the long form of the flag names.
#
# @param command
#   Optional command to be used as the container entry point.
#
# @param ensure
#   Valid values are 'present' or 'absent'
#
# @param enable
#   Status of the automatically generated systemd service for the container.
#   Valid values are 'running' or 'stopped'.
#
# @param update
#   When `true`, the container will be redeployed when a new container image is
#   detected in the container registry.  This is done by comparing the digest
#   value of the running container image with the digest of the registry image.
#   When `false`, the container will only be redeployed when the declared state
#   of the puppet resource is changed.
#
# @example
#   podman::container { 'jenkins':
#     image         => 'docker.io/jenkins/jenkins',
#     user          => 'jenkins',
#     flags         => {
#                      publish => [
#                                 '8080:8080',
#                                 '50000:50000',
#                                 ],
#                      volume  => 'jenkins:/var/jenkins_home',
#                      },
#     service_flags => { timeout => '60' },
#   }
#
define podman::container (
  String $image       = '',
  String $user        = '',
  Hash $flags         = {},
  Hash $service_flags = {},
  String $command     = '',
  String $ensure      = 'present',
  Boolean $enable     = true,
  Boolean $update     = true,
){
  #require podman::install

  # Add a label of base64 encoded flags defined for the container resource
  # This will be used to determine when the resource state is changed
  $flags_base64 = base64('encode', inline_template('<%= @flags.to_s %>')).chomp()

  # Add the default name and a custom label using the base64 encoded flags
  if has_key($flags, 'label') {
    $label = [] + $flags['label'] + "puppet_resource_flags=${flags_base64}"
    $no_label = $flags.delete('label')
  } else {
    $label = "puppet_resource_flags=${flags_base64}"
    $no_label = $flags
  }

  # If a container name is not set, use the Puppet resource name
  $merged_flags = merge({ name => $title, label => $label}, $no_label )
  $container_name = $merged_flags['name']

  # A rootless container will run as the defined user
  if $user != '' {
    ensure_resource('podman::rootless', $user, {})
    $systemctl = 'systemctl --user '

    # The handle is used to ensure resources have unique names
    $handle = "${user}-${container_name}"

    # Set default execution environment for the rootless user
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
      environment => [
        "HOME=${User[$user]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$user]['uid']}",
      ],
      cwd         => User[$user]['home'],
      user        => $user,
    }
    $requires = [
      Podman::Rootless[$user],
      Service['systemd-logind'],
    ]
    $service_unit_file ="${User[$user]['home']}/.config/systemd/user/podman-${container_name}.service"

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
    $_podman_systemd_reload = Exec["podman_systemd_${user}_reload"]
  } else {
    $systemctl = 'systemctl '
    $handle = $container_name
    $service_unit_file = "/etc/systemd/system/podman-${container_name}.service"
    $exec_defaults = {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
    }

    # Reload systemd when service files are updated
    ensure_resource('Exec', 'podman_systemd_reload', {
        path        => '/sbin:/usr/sbin:/bin:/usr/bin',
        command     => "${systemctl} daemon-reload",
        refreshonly => true,
      }
    )
    $requires = []
    $_podman_systemd_reload = Exec['podman_systemd_reload']
  }

  case $ensure {
    'present': {
      if $image == '' { fail('A source image is required') }

      # Detect changes to the defined podman flags and re-deploy if needed
      Exec { "verify_container_flags_${handle}":
        command  => 'true',
        provider => 'shell',
        unless   => @("END"/$L),
                   if podman container exists ${container_name}
                     then
                     saved_resource_flags="\$(podman container inspect ${container_name} \
                       --format '{{.Config.Labels.puppet_resource_flags}}' | tr -d '\n')"
                     current_resource_flags="\$(echo '${flags_base64}' | tr -d '\n')"
                     test "\${saved_resource_flags}" = "\${current_resource_flags}"
                   fi
                   |END
        notify   => Exec["podman_remove_container_${handle}"],
        require  => $requires,
        *        => $exec_defaults,
      }

      # Re-deploy when $update is true and the container image has been updated
      if $update {
        Exec { "verify_container_image_${handle}":
          command  => 'true',
          provider => 'shell',
          unless   => @("END"/$L),
            if podman container exists ${container_name}
              then
              image_name=\$(podman container inspect ${container_name} --format '{{.ImageName}}')
              running_digest=\$(podman image inspect \${image_name} --format '{{.Digest}}')
              latest_digest=\$(skopeo inspect docker://${image} | \
                /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
              [[ $? -ne 0 ]] && latest_digest=\$(skopeo inspect --no-creds docker://${image} | \
                /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
              test -z "\${latest_digest}" && exit 0     # Do not update if unable to get latest digest
              test "\${running_digest}" = "\${latest_digest}"
            fi
            |END
          notify   => [
            Exec["podman_remove_image_${handle}"],
            Exec["podman_remove_container_${handle}"],
          ],
          require  => $requires,
          *        => $exec_defaults,
        }
      } else {
        # Re-deploy when $update is false but the resource image has changed
        Exec { "verify_container_image_${handle}":
          command  => 'true',
          provider => 'shell',
          unless   => @("END"/$L),
            if podman container exists ${container_name}
              then
              running=\$(podman container inspect ${container_name} --format '{{.ImageName}}' | awk -F/ '{print \$NF}')
              declared=\$(echo "${image}" | awk -F/ '{print \$NF}')
              available=\$(skopeo inspect docker://${image} | \
                /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Name"]')
              test -z "\${available}" && exit 0     # Do not update update if unable to get the new image
              test "\${running}" = "\${declared}"
            fi
            |END
          notify   => [
            Exec["podman_remove_image_${handle}"],
            Exec["podman_remove_container_${handle}"],
          ],
          require  => $requires,
          *        => $exec_defaults,
        }
      }

      Exec { "podman_remove_image_${handle}":
        # Try to remove the image, but exit with success regardless
        provider    => 'shell',
        command     => "podman rmi ${image} || exit 0",
        refreshonly => true,
        notify      => Exec["podman_create_${handle}"],
        require     => [ $requires, Exec["podman_remove_container_${handle}"]],
        *           => $exec_defaults,
      }

      Exec { "podman_remove_container_${handle}":
        # Try nicely to stop the container, but then insist
        provider    => 'shell',
        command     => @("END"/L),
                       ${systemctl} stop podman-${container_name} || podman container stop --time 60 ${container_name}
                       podman container rm --force ${container_name}
                       |END
        refreshonly => true,
        notify      => Exec["podman_create_${handle}"],
        require     => $requires,
        *           => $exec_defaults,
      }

      # Convert $merged_flags hash to usable command arguments
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

      # Convert $service_flags hash to command arguments
      $_service_flags = $service_flags.reduce('') |$mem, $flag| {
        "${mem} --${flag[0]} '${flag[1]}'"
      }

      Exec { "podman_create_${handle}":
        command => "podman container create ${_flags} ${image} ${command}",
        unless  => "podman container exists ${container_name}",
        notify  => Exec["podman_generate_service_${handle}"],
        require => $requires,
        *       => $exec_defaults,
      }

      if $user != '' {
        Exec { "podman_generate_service_${handle}":
          command     => "podman generate systemd ${_service_flags} ${container_name} > ${service_unit_file}",
          refreshonly => true,
          notify      => Exec["service_podman_${handle}"],
          require     => $requires,
          *           => $exec_defaults,
        }

        # Work-around for managing user systemd services
        if $enable { $action = 'start'; $startup = 'enable' }
          else { $action = 'stop'; $startup = 'disable'
        }
        Exec { "service_podman_${handle}":
          command => @("END"/L),
                     ${systemctl} ${startup} podman-${container_name}.service
                     ${systemctl} ${action} podman-${container_name}.service
                     |END
          unless  => @("END"/L),
                     ${systemctl} is-active podman-${container_name}.service && \
                       ${systemctl} is-enabled podman-${container_name}.service
                     |END
          require => $requires,
          *       => $exec_defaults,
        }
      }
      else {
        Exec { "podman_generate_service_${handle}":
          path        => '/sbin:/usr/sbin:/bin:/usr/bin',
          command     => "podman generate systemd ${_service_flags} ${container_name} > ${service_unit_file}",
          refreshonly => true,
          notify      => Service["podman-${handle}"],
        }

        # Configure the container service per parameters
        if $enable { $state = 'running'; $startup = 'true' }
          else { $state = 'stopped'; $startup = 'false'
        }
        Service { "podman-${handle}":
          ensure => $state,
          enable => $startup,
        }
      }
    }

    'absent': {
      Exec { "service_podman_${handle}":
        command => @("END"/L),
                   ${systemctl} stop podman-${container_name}
                   ${systemctl} disable podman-${container_name}
                   |END
        onlyif  => @("END"/$L),
                   test "\$(${systemctl} is-active podman-${container_name} 2>&1)" = "active" -o \
                     "\$(${systemctl} is-enabled podman-${container_name} 2>&1)" = "enabled"
                   |END
        notify  => Exec["podman_remove_container_${handle}"],
        require => $requires,
        *       => $exec_defaults,
      }

      Exec { "podman_remove_container_${handle}":
        # Try nicely to stop the container, but then insist
        command => "podman container rm --force ${container_name}",
        unless  => "podman container exists ${container_name}; test $? -eq 1",
        notify  => Exec["podman_remove_image_${handle}"],
        require => $requires,
        *       => $exec_defaults,
      }

      Exec { "podman_remove_image_${handle}":
        # Try to remove the image, but exit with success regardless
        provider    => 'shell',
        command     => "podman rmi ${image} || exit 0",
        refreshonly => true,
        require     => [ $requires, Exec["podman_remove_container_${handle}"]],
        *           => $exec_defaults,
      }

      File { $service_unit_file:
        ensure  => absent,
        require => [
          $requires,
          Exec["service_podman_${handle}"],
        ],
        notify  => $_podman_systemd_reload,
      }
    }

    default: {
      fail('"ensure" must be "present" or "absent"')
    }
  }
}

