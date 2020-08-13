# @summary manage podman container and register as a systemd service
#
# @param image String $image,
#
# @param user String
#   Optional user for running rootless containers
#
# @param homedir String
#   The `homedir` parameter is required when `user` is defined.  Defining it
#   this way avoids using an external fact to lookup the home directory of
#   all users.
#
# @param flags Hash
#   All flags for the 'podman container create' command are supported via the
#   'flags' hash parameter, using only the long form of the flag name.  The
#   container name will be set as the resource name (namevar) unless the 'name'
#   flag is included in the flags hash.
#
# @param service_flags Hash
#   When a container is created, a systemd unit file for the container service
#   is generated using the 'podman generate systemd' command.  All flags for the
#   command are supported using the 'service_flags" hash parameter, again using
#   only the long form of the flag names.
#
# @param command String
#   Optional command to be used as the container entry point.
#
# @param ensure String
#   State of the automatically generated systemd service for the container.
#   Valid values are 'running' or 'stopped'.
#
# @param enable Boolean
#   Status of the automatically generated systemd service for the container.
#   Default is `true`
#
# @param update Boolean
#   When `true`, the container will be redeployed when a new container image is
#   detected in the container registry.  This is done by comparing the digest
#   value of the running container image with the digest of the registry image.
#   Default is `true`
#
# @example
#   podman::container { 'jenkins':
#     image         => 'docker.io/jenkins/jenkins',
#     user          => 'jenkins',
#     homedir       => '/home/jenkins',
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
  String $image,
  String $user        = '',
  String $homedir     = '',
  Hash $flags         = {},
  Hash $service_flags = {},
  String $command     = '',
  String $ensure      = 'present',
  Boolean $enable     = true,
  Boolean $update     = true,
){
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

  # A rootless container will run as the defined user
  if $user == '' {
    $merged_flags = merge({ name => $title, label => $label}, $no_label )
    Exec { path => '/sbin:/usr/sbin:/bin:/usr/bin' }
  } else {
    $merged_flags = merge({ name => "${user}_${title}", label => $label}, $no_label )
    Exec {
      path        => '/sbin:/usr/sbin:/bin:/usr/bin',
      user        => $user,
      environment => [ "HOME=${homedir}", ],
    }
  }
  $container_name = $merged_flags['name']


  case $ensure {
    'present': {
      # Detect changes to the defined resource state and re-deploy if needed
      Exec { "verify_container_state_${container_name}":
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
        notify   => Exec["podman_remove_container_${container_name}"],
      }

      # Re-deploy when the container image has been updated
      if $update {
        Exec { "verify_container_image_${container_name}":
          command  => 'true',
          provider => 'shell',
          unless   => @("END"/$L),
            if podman container exists ${container_name}
              then
              image_name=\$(podman container inspect ${container_name} --format '{{.ImageName}}')
              running_digest=\$(podman image inspect \${image_name} --format '{{.Digest}}')
              latest_digest=\$(skopeo inspect docker://\${image_name} | /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
              [[ $? -ne 0 ]] && latest_digest=\$(skopeo inspect --no-creds docker://\${image_name} | /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
              test -z "\${latest_digest}" && exit 0                     # Do not attempt to update if unable to get latest digest
              echo "running_digest: \${running_digest}" >/tmp/digest
              echo "latest_digest: \${latest_digest}" >>/tmp/digest
              test "\${running_digest}" = "\${latest_digest}"
            fi
            |END
          notify   => Exec["podman_remove_container_${container_name}"],
        }
      }

      Exec { "podman_remove_container_${container_name}":
        # Try nicely to stop the container, but then insist
        command     => @("END"/L),
                       systemctl stop podman-${container_name} || \
                         podman container stop --time 60 ${container_name}
                       podman container rm --force ${container_name}
                       |END
        refreshonly => true,
        notify      => Exec["podman_create_${container_name}"],
      }

      # Convert $merged_flags hash to usable command arguments
      $_flags = $merged_flags.reduce('') |$mem, $flag| {
        if $flag[1] =~ String {
          "${mem} --${flag[0]} '${flag[1]}'"
        } else {
          $dup = $flag[1].reduce('') |$mem2, $value| {
            "${mem2} --${flag[0]} '${value}'"
          }
          "${mem} ${dup}"
        }
      }

      # Convert $service_flags hash to command arguments
      $_service_flags = $service_flags.reduce('') |$mem, $flag| {
        "${mem} --${flag[0]} \"${flag[1]}\""
      }


      if $user != '' {
        ensure_resource('Exec', "tmpfies_clean_${user}", {
            command  => "echo \"# FILE MANAGED BY PUPPET\nR! /tmp/run-\$(id -u ${user})\" >\"/etc/tmpfiles.d/${user}-podman.conf\"",
            provider => 'shell',
            user     => 'root',
            creates  => "/etc/tmpfiles.d/${user}-podman.conf",
          }
        )

        Exec { "podman_create_${container_name}":
          command => "podman container create ${_flags} ${image} ${command}",
          unless  => "podman container exists ${container_name}",
          notify  => Exec["podman_tmp_${container_name}_service"],
        }

        Exec { "podman_tmp_${container_name}_service":
          command     => @("END"/L),
                         podman generate systemd ${_service_flags} ${container_name} \
                          > "/var/tmp/podman-${container_name}.service"
                         |END
          refreshonly => true,
          notify      => Exec["podman_${container_name}_service"],
        }

        Exec { "podman_${container_name}_service":
          command     => @("END"/L),
                         cp "/var/tmp/podman-${container_name}.service" \
                           "/etc/systemd/system/podman-${container_name}.service" && \
                         rm "/var/tmp/podman-${container_name}.service"
                         |END
          refreshonly => true,
          notify      => Ini_setting["podman_${container_name}_service"],
          user        => 'root',
        }

        Ini_setting { "podman_${container_name}_service":
          ensure  => 'present',
          path    => "/etc/systemd/system/podman-${container_name}.service",
          section => 'Service',
          setting => 'User',
          value   => $user,
          notify  => [
            Exec['podman_systemd_reload'],
            Service["podman-${container_name}"],
          ],
        }
      } else {
        Exec { "podman_create_${container_name}":
          command => "podman container create ${_flags} ${image} ${command}",
          unless  => "podman container exists ${container_name}",
          notify  => Exec["podman_${container_name}_service"],
        }

        Exec { "podman_${container_name}_service":
          command     => @("END"/L),
                         podman generate systemd ${_service_flags} ${container_name} \
                          > "/etc/systemd/system/podman-${container_name}.service"
                         |END
          refreshonly => true,
          notify      => [
            Exec['podman_systemd_reload'],
            Service["podman-${container_name}"],
          ],
        }
      }

      # Configure the container service per parameters
      if $enable { $running = 'running' } else { $running = 'stopped' }
      Service { "podman-${container_name}":
        ensure  => $running,
        enable  => $enable,
        require => Exec['podman_systemd_reload'],
      }
    }

    'absent': {
      Exec { "podman_remove_container_${container_name}":
        # Try nicely to stop the container, but then insist
        command => @("END"/L),
                   systemctl stop podman-${container_name} || \
                   podman container stop --time 60 ${container_name}
                   podman container rm --force ${container_name}
                   |END
        unless  => "podman container exists ${container_name}; test $? -eq 1",
      }

      File { "/etc/systemd/system/podman-${container_name}.service":
        ensure => absent,
        notify => Exec['podman_systemd_reload'],
      }
    }

    default: {
      fail('"ensure" must be "present" or "absent"')
    }
  }

  # Reload systemd when service files are updated
  ensure_resource('Exec', 'podman_systemd_reload', {
      command     => 'systemctl daemon-reload',
      refreshonly => true,
    }
  )
}
