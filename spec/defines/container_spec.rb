require 'spec_helper'

describe 'podman::container' do
  let(:title) { 'namevar' }
  let(:params) { { image: 'registry:latest' } }
  let(:pre_condition) { 'include podman' }

  on_supported_os.each do |os, os_facts|
    context "on #{os} with defaults for all parameters and image set to valid value" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('podman') }
      it { is_expected.to contain_class('podman::install') }

      it do
        is_expected.to contain_exec('podman_systemd_reload').only_with(
          {
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'command'     => 'systemctl  daemon-reload',
            'refreshonly' => true,
          },
        )
      end

      unless_flags = <<-END.gsub(%r{^\s+\|}, '')
        |if podman container exists namevar
        |  then
        |  saved_resource_flags="$(podman container inspect namevar     --format '{{.Config.Labels.puppet_resource_flags}}')"
        |  current_resource_flags="e30="
        |  test "${saved_resource_flags}" = "${current_resource_flags}"
        |fi
      END

      it do
        is_expected.to contain_exec('verify_container_flags_namevar').only_with(
          {
            'command'  => 'true',
            'provider' => 'shell',
            'unless'   => unless_flags,
            'notify'   => 'Exec[podman_remove_container_namevar]',
            'require'  => [],
            'path'     => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end

      if %r{^\/opt\/puppetlabs\/}.match?(os_facts[:ruby]['sitedir'])
        unless_image = <<-END.gsub(%r{^\s+\|}, '')
          |if podman container exists namevar
          |  then
          |  image_name=$(podman container inspect namevar --format '{{.ImageName}}')
          |  running_digest=$(podman image inspect $(podman image inspect ${image_name} --format='{{.ID}}') --format '{{.Digest}}')
          |  latest_digest=$(skopeo inspect docker://registry:latest |     /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
          |  [[ $? -ne 0 ]] && latest_digest=$(skopeo inspect --no-creds docker://registry:latest |     /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
          |  test -z "${latest_digest}" && exit 0     # Do not update if unable to get latest digest
          |  test "${running_digest}" = "${latest_digest}"
          |fi
        END
      else
        unless_image = <<-END.gsub(%r{^\s+\|}, '')
          |if podman container exists namevar
          |  then
          |  image_name=$(podman container inspect namevar --format '{{.ImageName}}')
          |  running_digest=$(podman image inspect $(podman image inspect ${image_name} --format='{{.ID}}') --format '{{.Digest}}')
          |  latest_digest=$(skopeo inspect docker://registry:latest |     /usr/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
          |  [[ $? -ne 0 ]] && latest_digest=$(skopeo inspect --no-creds docker://registry:latest |     /usr/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
          |  test -z "${latest_digest}" && exit 0     # Do not update if unable to get latest digest
          |  test "${running_digest}" = "${latest_digest}"
          |fi
        END
      end

      it do
        is_expected.to contain_exec('verify_container_image_namevar').only_with(
          {
            'command'  => 'true',
            'provider' => 'shell',
            'unless'   => unless_image,
            'notify'   => ['Exec[podman_remove_image_namevar]', 'Exec[podman_remove_container_namevar]'],
            'require'  => [],
            'path'     => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_remove_image_namevar').only_with(
          {
            'provider'    => 'shell',
            'command'     => 'podman rmi registry:latest || exit 0',
            'refreshonly' => true,
            'notify'   => 'Exec[podman_create_namevar]',
            'require'  => [ 'Exec[podman_remove_container_namevar]'],
            'path'     => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end

      remove_command = <<-END.gsub(%r{^\s+\|}, '')
        |systemctl  stop podman-namevar || true
        |podman container stop --time 60 namevar || true
        |podman container rm --force namevar || true
      END

      remove_onlyif = if %r{^\/opt\/puppetlabs\/}.match?(os_facts[:ruby]['sitedir'])
                        <<-END.gsub(%r{^\s+\|}, '')
          |test $(podman container inspect --format json namevar |/opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))[0]["State"]["Running"]') = true
        END
                      else
                        <<-END.gsub(%r{^\s+\|}, '')
          |test $(podman container inspect --format json namevar |/usr/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))[0]["State"]["Running"]') = true
        END
                      end

      it do
        is_expected.to contain_exec('podman_remove_container_namevar').only_with(
          {
            'provider'    => 'shell',
            'command'     => remove_command,
            'onlyif'      => remove_onlyif,
            'refreshonly' => true,
            'notify'      => 'Exec[podman_create_namevar]',
            'require'     => [],
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_create_namevar').only_with(
          {
            'command' => "podman container create  --name 'namevar' --label 'puppet_resource_flags=e30=' registry:latest ",
            'unless'  => 'podman container exists namevar',
            'notify'  => 'Exec[podman_generate_service_namevar]',
            'require' => [],
            'path'    => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_generate_service_namevar').only_with(
          {
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'command'     => 'podman generate systemd  namevar > /etc/systemd/system/podman-namevar.service',
            'refreshonly' => true,
            'notify'      => 'Service[podman-namevar]',
          },
        )
      end

      it do
        is_expected.to contain_service('podman-namevar').only_with(
          {
            'ensure' => 'running',
            'enable' => true,
          },
        )
      end

      # only here to reach 100% resource coverage]
      context 'cover additional resource from other classes' do
        it { is_expected.to contain_class('podman::options') }              # from podman
        it { is_expected.to contain_class('podman::service') }              # from podman
        it { is_expected.to contain_service('podman.socket') }              # from podman::service
        it { is_expected.to contain_file('/etc/containers/nodocker') }      # from podman::install
        it { is_expected.to contain_package('podman') }                     # from podman::install
        it { is_expected.to contain_package('skopeo') }                     # from podman::install

        if os_facts[:os]['selinux']['enabled'] == true
          it { is_expected.to contain_selboolean('container_manage_cgroup') } # from podman::install
        end
      end
    end
  end

  # The following tests are OS independent, so we only test one supported OS
  redhat = {
    supported_os: [
      {
        'operatingsystem'        => 'RedHat',
        'operatingsystemrelease' => ['9'],
      },
    ],
  }

  on_supported_os(redhat).each do |_os, os_facts|
    let(:facts) { os_facts }

    context 'with image set to valid testing:latest' do
      let(:params) { { image: 'testing:latest' } }

      unless_image = <<-END.gsub(%r{^\s+\|}, '')
        |if podman container exists namevar
        |  then
        |  image_name=$(podman container inspect namevar --format '{{.ImageName}}')
        |  running_digest=$(podman image inspect $(podman image inspect ${image_name} --format='{{.ID}}') --format '{{.Digest}}')
        |  latest_digest=$(skopeo inspect docker://testing:latest |     /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
        |  [[ $? -ne 0 ]] && latest_digest=$(skopeo inspect --no-creds docker://testing:latest |     /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
        |  test -z "${latest_digest}" && exit 0     # Do not update if unable to get latest digest
        |  test "${running_digest}" = "${latest_digest}"
        |fi
      END

      it { is_expected.to contain_exec('verify_container_image_namevar').with_unless(unless_image) }
      it { is_expected.to contain_exec('podman_remove_image_namevar').with_command('podman rmi testing:latest || exit 0') }
      it { is_expected.to contain_exec('podman_create_namevar').with_unless('podman container exists namevar') }
    end

    context 'with image set to valid testing:latest when update is set to valid false' do
      let(:params) { { image: 'testing:latest', update: false } }

      unless_image = <<-END.gsub(%r{^\s+\|}, '')
        |if podman container exists namevar
        |  then
        |  running=$(podman container inspect namevar --format '{{.ImageName}}' | awk -F/ '{print $NF}')
        |  declared=$(echo "testing:latest" | awk -F/ '{print $NF}')
        |  test "${running}" = "${declared}" && exit 0
        |  available=$(skopeo inspect docker://testing:latest |     /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Name"]')
        |  test -z "${available}" && exit 0     # Do not update update if unable to get the new image
        |  exit 1
        |fi
      END

      it { is_expected.to contain_exec('verify_container_image_namevar').with_unless(unless_image) }
    end

    context 'with image set to valid testing:latest when ensure is set to valid absent' do
      let(:params) { { image: 'testing:latest', ensure: 'absent' } }

      it { is_expected.to contain_exec('podman_remove_image_namevar').with_command('podman rmi testing:latest || exit 0') }
    end

    context 'with user set to valid testing' do
      let(:params) { { user: 'testing', image: 'mandatory:latest', } }
      let(:pre_condition) do
        "include podman
         # user & file needed by podman::rootless
         user { 'testing':
           ensure  => 'present',
           gid     => 1111,
           home    => '/home/testing',
           uid     => 3333,
         }
         file { '/home/testing': }
        "
      end

      it { is_expected.to contain_podman__rootless('testing').only_with({}) }

      it do
        is_expected.to contain_exec('podman_systemd_testing_reload').with(
          {
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_exec('verify_container_flags_testing-namevar').with(
          {
            'notify'      => 'Exec[podman_remove_container_testing-namevar]',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_exec('verify_container_image_testing-namevar').with(
          {
            'notify'      => ['Exec[podman_remove_image_testing-namevar]', 'Exec[podman_remove_container_testing-namevar]'],
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_remove_image_testing-namevar').with(
          {
            'notify'      => 'Exec[podman_create_testing-namevar]',
            'require'     => ['Podman::Rootless[testing]', 'Exec[podman_remove_container_testing-namevar]'],
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_remove_container_testing-namevar').with(
          {
            'notify'      => 'Exec[podman_create_testing-namevar]',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_create_testing-namevar').with(
          {
            'notify'      => 'Exec[podman_generate_service_testing-namevar]',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_generate_service_testing-namevar').only_with(
          {
            'command'     => 'podman generate systemd  namevar > /home/testing/.config/systemd/user/podman-namevar.service',
            'refreshonly' => true,
            'notify'      => 'Exec[service_podman_testing-namevar]',
            'require'     => ['Podman::Rootless[testing]'],
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_exec('service_podman_testing-namevar').only_with(
          {
            'command'     => "systemctl --user  enable podman-namevar.service\nsystemctl --user  start podman-namevar.service\n",
            'unless'      => "systemctl --user  is-active podman-namevar.service &&   systemctl --user  is-enabled podman-namevar.service\n",
            'require'     => ['Podman::Rootless[testing]'],
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      # only here to reach 100% resource coverage
      context 'cover additional resource from other classes' do
        it { is_expected.to contain_podman__rootless('testing') }
        it { is_expected.to contain_loginctl_user('testing') }                   # from podman::rootless
        it { is_expected.to contain_file('/home/testing/.config') }              # from podman::rootless
        it { is_expected.to contain_file('/home/testing/.config/systemd') }      # from podman::rootless
        it { is_expected.to contain_file('/home/testing/.config/systemd/user') } # from podman::rootless
        it { is_expected.to contain_exec('start_testing.slice') }                # from podman::rootless
      end
    end

    context 'with user set to valid testing when ensure is set to valid absent' do
      let(:params) { { user: 'testing', ensure: 'absent', image: 'mandatory:latest', } }
      let(:pre_condition) do
        "include podman
         # user & file needed by podman::rootless
         user { 'testing':
           ensure => 'present',
           gid    => 1111,
           home   => '/home/testing',
           uid    => 3333,
         }
         file { '/home/testing': }
        "
      end

      it { is_expected.to contain_podman__rootless('testing').only_with({}) }

      it do
        is_expected.to contain_exec('podman_systemd_testing_reload').with(
          {
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_exec('service_podman_testing-namevar').with(
          {
            'notify'      => 'Exec[podman_remove_container_testing-namevar]',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_remove_container_testing-namevar').with(
          {
            'notify'      => 'Exec[podman_remove_image_testing-namevar]',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_remove_image_testing-namevar').with(
          {
            'require'     => ['Podman::Rootless[testing]', 'Exec[podman_remove_container_testing-namevar]'],
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'user'        => 'testing',
          },
        )
      end

      it do
        is_expected.to contain_file('/home/testing/.config/systemd/user/podman-namevar.service').with(
          {
            'require' => ['Podman::Rootless[testing]', 'Exec[service_podman_testing-namevar]'],
          },
        )
      end
    end

    context 'with flags set to valid hash' do
      let(:params) { { flags: { publish: ['242:242'], volume: 'jenkins:/test/ing' }, image: 'mandatory:latest' } }
      let(:pre_condition) { 'include podman' }

      unless_flags = <<-END.gsub(%r{^\s+\|}, '')
        |if podman container exists namevar
        |  then
        |  saved_resource_flags="$(podman container inspect namevar     --format '{{.Config.Labels.puppet_resource_flags}}')"
        |  current_resource_flags="eyJwdWJsaXNoIj0+WyIyNDI6MjQyIl0sICJ2b2x1bWUiPT4iamVua2luczovdGVzdC9pbmcifQ=="
        |  test "${saved_resource_flags}" = "${current_resource_flags}"
        |fi
      END

      it { is_expected.to contain_exec('verify_container_flags_namevar').with_unless(unless_flags) }

      it do
        is_expected.to contain_exec('podman_create_namevar').with(
          {
            'command' => "podman container create  --name 'namevar' " \
              "--label 'puppet_resource_flags=eyJwdWJsaXNoIj0+WyIyNDI6MjQyIl0sICJ2b2x1bWUiPT4iamVua2luczovdGVzdC9pbmcifQ=='  " \
              "--publish '242:242' --volume 'jenkins:/test/ing' mandatory:latest ",
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_generate_service_namevar').with(
          {
            'command' => 'podman generate systemd  namevar > /etc/systemd/system/podman-namevar.service',
          },
        )
      end
    end

    context 'with flags set to valid hash containing a label' do
      let(:params) { { flags: { publish: ['242:242'], volume: 'jenkins:/test/ing', label: 'test' }, image: 'mandatory:latest' } }
      let(:pre_condition) { 'include podman' }

      unless_flags = <<-END.gsub(%r{^\s+\|}, '')
        |if podman container exists namevar
        |  then
        |  saved_resource_flags="$(podman container inspect namevar     --format '{{.Config.Labels.puppet_resource_flags}}')"
        |  current_resource_flags="eyJwdWJsaXNoIj0+WyIyNDI6MjQyIl0sICJ2b2x1bWUiPT4iamVua2luczovdGVzdC9pbmciLCAibGFiZWwiPT4idGVzdCJ9"
        |  test "${saved_resource_flags}" = "${current_resource_flags}"
        |fi
      END

      it { is_expected.to contain_exec('verify_container_flags_namevar').with_unless(unless_flags) }

      it do
        is_expected.to contain_exec('podman_create_namevar').with(
          {
            'command' => "podman container create  --name 'namevar'  --label 'test' " \
              "--label 'puppet_resource_flags=eyJwdWJsaXNoIj0+WyIyNDI6MjQyIl0sICJ2b2x1bWUiPT4iamVua2luczovdGVzdC9pbmciLCAibGFiZWwiPT4idGVzdCJ9'  " \
              "--publish '242:242' --volume 'jenkins:/test/ing' mandatory:latest ",
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_generate_service_namevar').with(
          {
            'command' => 'podman generate systemd  namevar > /etc/systemd/system/podman-namevar.service',
          },
        )
      end
    end

    context 'with flags set to valid hash when user is set to valid testing' do
      let(:params) { { flags: { publish: ['242:242'], volume: 'jenkins:/test/ing' }, user: 'testing', image: 'mandatory:latest' } }
      let(:pre_condition) do
        "include podman
         # user & file needed by podman::rootless
         user { 'testing':
           ensure => 'present',
           gid    => 1111,
           home   => '/home/testing',
           uid    => 3333,
         }
         file { '/home/testing': }
        "
      end

      unless_flags = <<-END.gsub(%r{^\s+\|}, '')
        |if podman container exists namevar
        |  then
        |  saved_resource_flags="$(podman container inspect namevar     --format '{{.Config.Labels.puppet_resource_flags}}')"
        |  current_resource_flags="eyJwdWJsaXNoIj0+WyIyNDI6MjQyIl0sICJ2b2x1bWUiPT4iamVua2luczovdGVzdC9pbmcifQ=="
        |  test "${saved_resource_flags}" = "${current_resource_flags}"
        |fi
      END

      it { is_expected.to contain_exec('verify_container_flags_testing-namevar').with_unless(unless_flags) }

      it do
        is_expected.to contain_exec('podman_create_testing-namevar').with(
          {
            'command' => "podman container create  --name 'namevar' " \
              "--label 'puppet_resource_flags=eyJwdWJsaXNoIj0+WyIyNDI6MjQyIl0sICJ2b2x1bWUiPT4iamVua2luczovdGVzdC9pbmcifQ=='  " \
              "--publish '242:242' --volume 'jenkins:/test/ing' mandatory:latest ",
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_generate_service_testing-namevar').with(
          {
            'command' => 'podman generate systemd  namevar > /home/testing/.config/systemd/user/podman-namevar.service',
          },
        )
      end

      it do
        is_expected.to contain_exec('service_podman_testing-namevar').with(
          {
            'command' => "systemctl --user  enable podman-namevar.service\nsystemctl --user  start podman-namevar.service\n",
            'unless'  => "systemctl --user  is-active podman-namevar.service &&   systemctl --user  is-enabled podman-namevar.service\n",
          },
        )
      end
    end

    context 'with command set to valid /test/ing' do
      let(:params) { { command: '/test/ing', image: 'mandatory:latest' } }
      let(:pre_condition) { 'include podman' }

      it do
        is_expected.to contain_exec('podman_create_namevar').with(
          {
            'command' => "podman container create  --name 'namevar' --label 'puppet_resource_flags=e30=' mandatory:latest /test/ing",
          },
        )
      end
    end

    context 'with ensure set to valid absent' do
      let(:params) { { ensure: 'absent', image: 'mandatory:latest' } }
      let(:pre_condition) { 'include podman' }

      it do
        is_expected.to contain_exec('service_podman_namevar').only_with(
          {
            'command' => "systemctl  stop podman-namevar\nsystemctl  disable podman-namevar\n",
            'onlyif'  => "test \"$(systemctl  is-active podman-namevar 2>&1)\" = \"active\" -o   \"$(systemctl  is-enabled podman-namevar 2>&1)\" = \"enabled\"\n",
            'notify'  => 'Exec[podman_remove_container_namevar]',
            'require' => [],
            'path'    => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_remove_container_namevar').only_with(
          {
            'command' => 'podman container rm --force namevar',
            'unless'  => 'podman container exists namevar; test $? -eq 1',
            'notify'  => 'Exec[podman_remove_image_namevar]',
            'require' => [],
            'path'    => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_remove_image_namevar').only_with(
          {
            'provider'    => 'shell',
            'command'     => 'podman rmi mandatory:latest || exit 0',
            'refreshonly' => true,
            'require'     => ['Exec[podman_remove_container_namevar]'],
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end

      it do
        is_expected.to contain_file('/etc/systemd/system/podman-namevar.service').only_with(
          {
            'ensure'  => 'absent',
            'require' => ['Exec[service_podman_namevar]'],
            'notify'  => 'Exec[podman_systemd_reload]',
          },
        )
      end
    end

    context 'with ensure set to valid absent when user is set to valid value' do
      let(:params) { { ensure: 'absent', user: 'user', image: 'mandatory:latest' } }
      let(:pre_condition) do
        "include podman
         # user & file needed by podman::rootless
         user { 'user':
           ensure => 'present',
           gid    => 1111,
           home   => '/home/user',
           uid    => 3333,
         }
         file { '/home/user': }
        "
      end

      it { is_expected.to contain_podman__rootless('user').only_with({}) }

      it do
        is_expected.to contain_exec('podman_systemd_user_reload').only_with(
          {
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'command'     => 'systemctl --user  daemon-reload',
            'refreshonly' => true,
            'environment' => ['HOME=/home/user', 'XDG_RUNTIME_DIR=/run/user/3333'],
            'cwd'         => '/home/user',
            'provider'    => 'shell',
            'user'        => 'user',
          },
        )
      end

      it do
        is_expected.to contain_exec('service_podman_user-namevar').only_with(
          {
            'command'     => "systemctl --user  stop podman-namevar\nsystemctl --user  disable podman-namevar\n",
            'onlyif'      => "test \"$(systemctl --user  is-active podman-namevar 2>&1)\" = \"active\" -o   \"$(systemctl --user  is-enabled podman-namevar 2>&1)\" = \"enabled\"\n",
            'notify'      => 'Exec[podman_remove_container_user-namevar]',
            'require'     => ['Podman::Rootless[user]'],
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/user', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/user',
            'user'        => 'user',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_remove_container_user-namevar').only_with(
          {
            'command'     => 'podman container rm --force namevar',
            'unless'      => 'podman container exists namevar; test $? -eq 1',
            'notify'      => 'Exec[podman_remove_image_user-namevar]',
            'require'     => ['Podman::Rootless[user]'],
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/user', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/user',
            'user'        => 'user',
          },
        )
      end

      it do
        is_expected.to contain_exec('podman_remove_image_user-namevar').only_with(
          {
            'provider'    => 'shell',
            'command'     => 'podman rmi mandatory:latest || exit 0',
            'refreshonly' => true,
            'require'     => ['Podman::Rootless[user]', 'Exec[podman_remove_container_user-namevar]'],
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/user', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/user',
            'user'        => 'user',
          },
        )
      end

      it do
        is_expected.to contain_file('/home/user/.config/systemd/user/podman-namevar.service').only_with(
          {
            'ensure'  => 'absent',
            'require' => ['Podman::Rootless[user]', 'Exec[service_podman_user-namevar]'],
            'notify'  => 'Exec[podman_systemd_user_reload]',
          },
        )
      end

      # only here to reach 100% resource coverage]
      context 'cover additional resource from other classes' do
        it { is_expected.to contain_podman__rootless('user') }
        it { is_expected.to contain_loginctl_user('user') }                   # from podman::rootless
        it { is_expected.to contain_file('/home/user/.config') }              # from podman::rootless
        it { is_expected.to contain_file('/home/user/.config/systemd') }      # from podman::rootless
        it { is_expected.to contain_file('/home/user/.config/systemd/user') } # from podman::rootless
        it { is_expected.to contain_exec('start_user.slice') }                # from podman::rootless
      end
    end

    context 'with enable set to valid false' do
      let(:params) { { enable: false, image: 'mandatory:latest' } }
      let(:pre_condition) { 'include podman' }

      it do
        is_expected.to contain_service('podman-namevar').only_with(
          {
            'ensure' => 'stopped',
            'enable' => false,
          },
        )
      end
    end

    context 'with enable set to valid false when user is set to valid value' do
      let(:params) { { enable: false, user: 'user', image: 'mandatory:latest' } }
      let(:pre_condition) do
        "include podman
         # user & file needed by podman::rootless
         user { 'user':
           ensure => 'present',
           gid    => 1111,
           home   => '/home/user',
           uid    => 3333,
         }
         file { '/home/user': }
        "
      end

      it do
        is_expected.to contain_exec('service_podman_user-namevar').with(
          {
            'command' => "systemctl --user  disable podman-namevar.service\nsystemctl --user  stop podman-namevar.service\n",
          },
        )
      end

      it { is_expected.to contain_exec('verify_container_flags_user-namevar') }
      it { is_expected.to contain_exec('verify_container_image_user-namevar') }
      it { is_expected.to contain_exec('podman_create_user-namevar') }
      it { is_expected.to contain_exec('podman_generate_service_user-namevar') }
    end

    context 'with update set to valid false' do
      let(:params) { { update: false, image: 'mandatory:latest' } }
      let(:pre_condition) { 'include podman' }

      unless_image = <<-END.gsub(%r{^\s+\|}, '')
        |if podman container exists namevar
        |  then
        |  running=$(podman container inspect namevar --format '{{.ImageName}}' | awk -F/ '{print $NF}')
        |  declared=$(echo "mandatory:latest" | awk -F/ '{print $NF}')
        |  test "\${running}" = "\${declared}" && exit 0
        |  available=$(skopeo inspect docker://mandatory:latest |     /opt/puppetlabs/puppet/bin/ruby -rjson -e 'puts (JSON.parse(STDIN.read))["Name"]')
        |  test -z "\${available}" && exit 0     # Do not update update if unable to get the new image
        |  exit 1
        |fi
      END

      it do
        is_expected.to contain_exec('verify_container_image_namevar').only_with(
          {
            'command'  => 'true',
            'provider' => 'shell',
            'unless'   => unless_image,
            'notify'   => ['Exec[podman_remove_image_namevar]', 'Exec[podman_remove_container_namevar]'],
            'require'  => [],
            'path'     => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end
    end

    context 'with ruby set to valid /test/ing' do
      let(:params) { { ruby: '/test/ing', image: 'mandatory:latest' } }
      let(:pre_condition) { 'include podman' }

      unless_ruby = <<-END.gsub(%r{^\s+\|}, '')
        |if podman container exists namevar
        |  then
        |  image_name=$(podman container inspect namevar --format '{{.ImageName}}')
        |  running_digest=$(podman image inspect $(podman image inspect ${image_name} --format='{{.ID}}') --format '{{.Digest}}')
        |  latest_digest=$(skopeo inspect docker://mandatory:latest |     /test/ing -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
        |  [[ $? -ne 0 ]] && latest_digest=$(skopeo inspect --no-creds docker://mandatory:latest |     /test/ing -rjson -e 'puts (JSON.parse(STDIN.read))["Digest"]')
        |  test -z "${latest_digest}" && exit 0     # Do not update if unable to get latest digest
        |  test "${running_digest}" = "${latest_digest}"
        |fi
      END

      it { is_expected.to contain_exec('verify_container_image_namevar').with_unless(unless_ruby) }

      onlyif_ruby = <<-END.gsub(%r{^\s+\|}, '')
        |test $(podman container inspect --format json namevar |/test/ing -rjson -e 'puts (JSON.parse(STDIN.read))[0]["State"]["Running"]') = true
      END

      it { is_expected.to contain_exec('podman_remove_container_namevar').with_onlyif(onlyif_ruby) }
    end

    context 'with ruby set to valid /test/ing when update is false' do
      let(:params) { { ruby: '/test/ing', update: false, image: 'mandatory:latest' } }
      let(:pre_condition) { 'include podman' }

      unless_ruby = <<-END.gsub(%r{^\s+\|}, '')
        |if podman container exists namevar
        |  then
        |  running=$(podman container inspect namevar --format '{{.ImageName}}' | awk -F/ '{print $NF}')
        |  declared=$(echo "mandatory:latest" | awk -F/ '{print $NF}')
        |  test "\${running}" = "\${declared}" && exit 0
        |  available=$(skopeo inspect docker://mandatory:latest |     /test/ing -rjson -e 'puts (JSON.parse(STDIN.read))["Name"]')
        |  test -z "\${available}" && exit 0     # Do not update update if unable to get the new image
        |  exit 1
        |fi
      END

      it { is_expected.to contain_exec('verify_container_image_namevar').with_unless(unless_ruby) }

      onlyif_ruby = <<-END.gsub(%r{^\s+\|}, '')
        |test $(podman container inspect --format json namevar |/test/ing -rjson -e 'puts (JSON.parse(STDIN.read))[0]["State"]["Running"]') = true
      END

      it { is_expected.to contain_exec('podman_remove_container_namevar').with_onlyif(onlyif_ruby) }
    end
  end
end
