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
#   command are supported using the 'service_flags' hash parameter, again using
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
# @param ruby
#   The absolute path to the ruby binary to use in scripts. The default path is
#   '/opt/puppetlabs/puppet/bin/ruby' for Puppetlabs packaged puppet, and
#   '/usr/bin/ruby' for all others. 
#
# @param create_timeout
#   The timeout value for the container create command.
#   This is used to override the default timeout of 300 seconds. 
#   This is needed when deploying containers that take longer to create.
#   The value can be set to 0 to disable the timeout.
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
  Optional[String]                $image          = undef,
  Optional[String]                $user           = undef,
  Hash                            $flags          = {},
  Hash                            $service_flags  = {},
  Optional[String]                $command        = undef,
  Enum['present', 'absent']       $ensure         = 'present',
  Boolean                         $enable         = true,
  Boolean                         $update         = true,
  Optional[Stdlib::Unixpath]      $ruby           = undef,
  Variant[Undef, Integer, String] $create_timeout = undef,
) {
  require podman::install

  $installed_ruby = $facts['ruby']['sitedir'] ? {
    /^\/opt\/puppetlabs\// => '/opt/puppetlabs/puppet/bin/ruby',
    default                => '/usr/bin/ruby',
  }

  $_ruby = pick($ruby, $installed_ruby)

  # Add a label of base64 encoded flags defined for the container resource
  # This will be used to determine when the resource state is changed
  $flags_base64 = base64('encode', inline_template('<%= @flags.to_s %>'), strict)

  # Add the default name and a custom label using the base64 encoded flags
  if 'label' in  $flags {
    $label = [] + $flags['label'] + "puppet_resource_flags=${flags_base64}"
    $no_label = $flags.delete('label')
  } else {
    $label = "puppet_resource_flags=${flags_base64}"
    $no_label = $flags
  }

  # If a container name is not set, use the Puppet resource name
  $merged_flags = stdlib::merge({ name => $title, label => $label }, $no_label )
  $container_name = $merged_flags['name']

  # A rootless container will run as the defined user
  if $user != undef and $user != '' {
    $systemctl = 'systemctl --user '
    $requires = [Podman::Rootless[$user]]
    $service_unit_file = "${User[$user]['home']}/.config/systemd/user/podman-${container_name}.service"
    $_podman_systemd_reload = Exec["podman_systemd_${user}_reload"]

    # The handle is used to ensure resources have unique names
    $handle = "${user}-${container_name}"

    # Set default execution environment for the rootless user
    $exec_defaults = {
      cwd         => User[$user]['home'],
      user        => $user,
      environment => [
        "HOME=${User[$user]['home']}",
        "XDG_RUNTIME_DIR=/run/user/${User[$user]['uid']}",
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${User[$user]['uid']}/bus",
      ],
    }

    ensure_resource('podman::rootless', $user, {})

    # Reload systemd when service files are updated
    ensure_resource('Exec', "podman_systemd_${user}_reload",
      {
        path        => '/sbin:/usr/sbin:/bin:/usr/bin',
        command     => "${systemctl} daemon-reload",
        refreshonly => true,
        environment => ["HOME=${User[$user]['home']}", "XDG_RUNTIME_DIR=/run/user/${User[$user]['uid']}"],
        cwd         => User[$user]['home'],
        provider    => 'shell',
        user        => $user,
      },
    )
  } else {
    $systemctl = 'systemctl '
    $requires = []
    $service_unit_file = "/etc/systemd/system/podman-${container_name}.service"
    $_podman_systemd_reload = Exec['podman_systemd_reload']
    $handle = $container_name
    $exec_defaults = {}

    # Reload systemd when service files are updated
    ensure_resource('Exec', 'podman_systemd_reload',
      {
        path        => '/sbin:/usr/sbin:/bin:/usr/bin',
        command     => "${systemctl} daemon-reload",
        refreshonly => true,
      },
    )
  }

  case $ensure {
    'present': {
      if $image == undef { fail('A source image is required') }

      # Detect changes to the defined podman flags and re-deploy if needed
      $unless_vcf = @("END"/$L)
        if podman container exists ${container_name}
          then
          saved_resource_flags="\$(podman container inspect ${container_name} \
            --format '{{.Config.Labels.puppet_resource_flags}}')"
          current_resource_flags="${flags_base64}"
          test "\${saved_resource_flags}" = "\${current_resource_flags}"
        fi
        | END

      exec { "verify_container_flags_${handle}":
        command  => 'true',
        provider => 'shell',
        unless   => $unless_vcf,
        notify   => Exec["podman_remove_container_${handle}"],
        require  => $requires,
        path     => '/sbin:/usr/sbin:/bin:/usr/bin',
        *        => $exec_defaults,
      }

      # Re-deploy when $update is true and the container image has been updated
      if $update {
        $unless_vci = @("END"/$L)
          if podman container exists ${container_name}
            then
            image_name=\$(podman container inspect ${container_name} --format '{{.ImageName}}')
            running_digest=\$(podman image inspect $(podman image inspect \${image_name} --format='{{.ID}}') --format '{{.Digest}}')
            latest_digest=\$(skopeo inspect docker://${image} | \
              ${_ruby} -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
            test $? -ne 0 && latest_digest=\$(skopeo inspect docker://${image} | \
              ${_ruby} -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
            test -z "\${latest_digest}" && exit 0     # Do not update if unable to get latest digest
            test "\${running_digest}" = "\${latest_digest}"
          fi
          | END

        exec { "verify_container_image_${handle}":
          command  => 'true',
          provider => 'shell',
          unless   => $unless_vci,
          notify   => [Exec["podman_remove_image_${handle}"], Exec["podman_remove_container_${handle}"]],
          require  => $requires,
          path     => '/sbin:/usr/sbin:/bin:/usr/bin',
          *        => $exec_defaults,
        }
      } else {
        # Re-deploy when $update is false but the resource image has changed
        $unless_vci = @("END"/$L)
          if podman container exists ${container_name}
            then
            running=\$(podman container inspect ${container_name} --format '{{.ImageName}}' | awk -F/ '{print \$NF}')
            declared=\$(echo "${image}" | awk -F/ '{print \$NF}')
            test "\${running}" = "\${declared}" && exit 0
            available=\$(skopeo inspect docker://${image} | \
              ${_ruby} -rjson -e 'puts (JSON.parse(STDIN.read))["Name"]')
            test -z "\${available}" && exit 0     # Do not update update if unable to get the new image
            exit 1
          fi
          | END

        exec { "verify_container_image_${handle}":
          command  => 'true',
          provider => 'shell',
          unless   => $unless_vci,
          notify   => [Exec["podman_remove_image_${handle}"], Exec["podman_remove_container_${handle}"]],
          require  => $requires,
          path     => '/sbin:/usr/sbin:/bin:/usr/bin',
          *        => $exec_defaults,
        }
      }

      # Try to remove the image, but exit with success regardless
      exec { "podman_remove_image_${handle}":
        provider    => 'shell',
        command     => "podman rmi ${image} || exit 0",
        refreshonly => true,
        notify      => Exec["podman_create_${handle}"],
        require     => [$requires, Exec["podman_remove_container_${handle}"]],
        path        => '/sbin:/usr/sbin:/bin:/usr/bin',
        *           => $exec_defaults,
      }

      $command_prc = @("END"/L)
        ${systemctl} stop podman-${container_name} || true
        podman container stop --time 60 ${container_name} || true
        podman container rm --force ${container_name} || true
        | END

      $onlyif_prc = @("END"/L)
        test $(podman container inspect --format json ${container_name} |\
        ${_ruby} -rjson -e 'puts (JSON.parse(STDIN.read))[0]["State"]["Running"]') = true
        | END

      # Try to stop the container service, then the container directly
      exec { "podman_remove_container_${handle}":
        provider    => 'shell',
        command     => $command_prc,
        onlyif      => $onlyif_prc,
        refreshonly => true,
        notify      => Exec["podman_create_${handle}"],
        require     => $requires,
        path        => '/sbin:/usr/sbin:/bin:/usr/bin',
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
        if $flag[1] =~ String {
          if $flag[1] == '' {
            "${mem} --${flag[0]}"
          } else {
            "${mem} --${flag[0]} '${flag[1]}'"
          }
        } elsif $flag[1] =~ Undef {
          "${mem} --${flag[0]}"
        } else {
          $dup = $flag[1].reduce('') |$mem2, $value| {
            "${mem2} --${flag[0]} '${value}'"
          }
          "${mem} ${dup}"
        }
      }

      exec { "podman_create_${handle}":
        command => "podman container create ${_flags} ${image} ${command}",
        unless  => "podman container exists ${container_name}",
        notify  => Exec["podman_generate_service_${handle}"],
        require => $requires,
        path    => '/sbin:/usr/sbin:/bin:/usr/bin',
        timeout => $create_timeout,
        *       => $exec_defaults,
      }

      if $user != undef and $user != '' {
        exec { "podman_generate_service_${handle}":
          command     => "podman generate systemd ${_service_flags} ${container_name} > ${service_unit_file}",
          refreshonly => true,
          notify      => Exec["service_podman_${handle}"],
          require     => $requires,
          path        => '/sbin:/usr/sbin:/bin:/usr/bin',
          *           => $exec_defaults,
        }

        # Work-around for managing user systemd services
        if $enable {
          $action = 'start'; $startup = 'enable'
        } else {
          $action = 'stop'; $startup = 'disable'
        }

        $command_sp = @("END"/L)
          ${systemctl} ${startup} podman-${container_name}.service
          ${systemctl} ${action} podman-${container_name}.service
          | END

        $unless_sp = @("END"/L)
          ${systemctl} is-active podman-${container_name}.service && \
            ${systemctl} is-enabled podman-${container_name}.service
          | END

        exec { "service_podman_${handle}":
          command => $command_sp,
          unless  => $unless_sp,
          require => $requires,
          path    => '/sbin:/usr/sbin:/bin:/usr/bin',
          *       => $exec_defaults,
        }
      } else {
        exec { "podman_generate_service_${handle}":
          path        => '/sbin:/usr/sbin:/bin:/usr/bin',
          command     => "podman generate systemd ${_service_flags} ${container_name} > ${service_unit_file}",
          refreshonly => true,
          notify      => Service["podman-${handle}"],
        }

        # Configure the container service per parameters
        if $enable {
          $state = 'running'; $startup = 'true'
        } else {
          $state = 'stopped'; $startup = 'false'
        }
        service { "podman-${handle}":
          ensure => $state,
          enable => $startup,
        }
      }
    }
    default: {
      $command_sp = @("END"/L)
        ${systemctl} stop podman-${container_name}
        ${systemctl} disable podman-${container_name}
        | END

      $onlyif_sp = @("END"/$L)
        test "\$(${systemctl} is-active podman-${container_name} 2>&1)" = "active" -o \
          "\$(${systemctl} is-enabled podman-${container_name} 2>&1)" = "enabled"
        | END

      exec { "service_podman_${handle}":
        command => $command_sp,
        onlyif  => $onlyif_sp,
        notify  => Exec["podman_remove_container_${handle}"],
        require => $requires,
        path    => '/sbin:/usr/sbin:/bin:/usr/bin',
        *       => $exec_defaults,
      }

      exec { "podman_remove_container_${handle}":
        command => "podman container rm --force ${container_name}",
        unless  => "podman container exists ${container_name}; test $? -eq 1",
        notify  => Exec["podman_remove_image_${handle}"],
        require => $requires,
        path    => '/sbin:/usr/sbin:/bin:/usr/bin',
        *       => $exec_defaults,
      }

      # Try to remove the image, but exit with success regardless
      exec { "podman_remove_image_${handle}":
        provider    => 'shell',
        command     => "podman rmi ${image} || exit 0",
        refreshonly => true,
        require     => [$requires, Exec["podman_remove_container_${handle}"]],
        path        => '/sbin:/usr/sbin:/bin:/usr/bin',
        *           => $exec_defaults,
      }

      file { $service_unit_file:
        ensure  => absent,
        require => [$requires, Exec["service_podman_${handle}"]],
        notify  => $_podman_systemd_reload,
      }
    }
  }
}
