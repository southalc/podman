require 'spec_helper'

describe 'podman::network' do
  let(:title) { 'testing-title' }
  let(:pre_condition) { 'include podman' }

  on_supported_os.each do |os, os_facts|
    context "on #{os} with defaults for all parameters" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it { is_expected.to contain_class('podman::install') }

      it do
        is_expected.to contain_exec('podman_create_network_testing-title').only_with(
          {
            'command' => 'podman network create testing-title --driver bridge',
            'unless'  => 'podman network exists testing-title',
            'path'    => '/sbin:/usr/sbin:/bin:/usr/bin',
            'require' => [],
          },
        )
      end

      # only here to reach 100% resource coverage
      it { is_expected.to contain_class('podman') }                       # from pre_condition
      it { is_expected.to contain_class('podman::options') }              # from podman
      it { is_expected.to contain_class('podman::service') }              # from podman
      it { is_expected.to contain_service('podman.socket') }              # from podman::service
      it { is_expected.to contain_file('/etc/containers/nodocker') }      # from podman::install
      it { is_expected.to contain_package('buildah') }                    # from podman::install
      it { is_expected.to contain_package('podman-compose') }             # from podman::install
      it { is_expected.to contain_package('podman-docker') }              # from podman::install
      it { is_expected.to contain_package('podman') }                     # from podman::install
      it { is_expected.to contain_package('skopeo') }                     # from podman::install
      if os_facts[:os]['family'] == 'Archlinux'
        it { is_expected.to contain_package('systemd') }                  # from podman::install
      else
        it { is_expected.to contain_package('systemd-container') }        # from podman::install
      end

      if os_facts[:os]['selinux']['enabled'] == true
        it { is_expected.to contain_selboolean('container_manage_cgroup') } # from podman::install
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

    context 'with ensure set to valid absent' do
      let(:params) { { ensure: 'absent' } }

      it do
        is_expected.to contain_exec('podman_remove_network_testing-title').only_with(
          {
            'command' => 'podman network rm testing-title',
            'onlyif'  => 'podman network exists testing-title',
            'path'    => '/sbin:/usr/sbin:/bin:/usr/bin',
            'require' => [],
          },
        )
      end
    end

    context 'with ensure set to valid absent when user is set to valid dummy' do
      let(:params) { { ensure: 'absent', user: 'dummy' } }
      let(:pre_condition) do
        "include podman
         ensure_resource('podman::rootless', 'dummy', {})
         # user & file needed by podman::rootless
         user { 'dummy':
           ensure  => 'present',
           gid     => 1111,
           home    => '/home/dummy',
           uid     => 3333,
         }
         file { '/home/dummy': }
        "
      end

      it do
        is_expected.to contain_exec('podman_remove_network_testing-title').only_with(
          {
            'command'     => 'podman network rm testing-title',
            'onlyif'      => 'podman network exists testing-title',
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'require'     => ['Podman::Rootless[dummy]', 'Service[podman systemd-logind]'],
            'user'        => 'dummy',
            'environment' => ['HOME=/home/dummy', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/dummy',
          },
        )
      end

      # only here to reach 100% resource coverage
      it { is_expected.to contain_exec('loginctl_linger_dummy') }            # from podman::rootless
      it { is_expected.to contain_exec('start_dummy.slice') }                # from podman::rootless
      it { is_expected.to contain_file('/home/dummy/.config') }              # from podman::rootless
      it { is_expected.to contain_file('/home/dummy/.config/systemd') }      # from podman::rootless
      it { is_expected.to contain_file('/home/dummy/.config/systemd/user') } # from podman::rootless
      it { is_expected.to contain_service('podman systemd-logind') }         # from podman::rootless
    end

    context 'with driver set to valid macvlan' do
      let(:params) { { driver: 'macvlan' } }

      it do
        is_expected.to contain_exec('podman_create_network_testing-title').with(
          {
            'command' => 'podman network create testing-title --driver macvlan',
          },
        )
      end
    end

    # disable_dns currently has no functionality
    context 'with disable_dns set to valid true' do
      let(:params) { { disable_dns: true } }

      it { is_expected.to compile }
    end

    context 'with opts set to valid array [test, ing]' do
      let(:params) { { opts: ['test', 'ing'] } }

      it do
        is_expected.to contain_exec('podman_create_network_testing-title').with(
          {
            'command' => 'podman network create testing-title --driver bridge --flag test --flag ing',
          },
        )
      end
    end

    context 'with gateway set to valid testing' do
      let(:params) { { gateway: 'testing' } }

      it do
        is_expected.to contain_exec('podman_create_network_testing-title').with(
          {
            'command' => 'podman network create testing-title --driver bridge --gateway testing',
          },
        )
      end
    end

    context 'with internal set to valid true' do
      let(:params) { { internal: true } }

      it do
        is_expected.to contain_exec('podman_create_network_testing-title').with(
          {
            'command' => 'podman network create testing-title --driver bridge --internal',
          },
        )
      end
    end

    context 'with ip_range set to valid testing' do
      let(:params) { { ip_range: 'testing' } }

      it do
        is_expected.to contain_exec('podman_create_network_testing-title').with(
          {
            'command' => 'podman network create testing-title --driver bridge --ip-range testing',
          },
        )
      end
    end

    context 'with labels set to valid hash' do
      let(:params) { { labels: { test: 'ing', test2: 'ing2' } } }

      it do
        is_expected.to contain_exec('podman_create_network_testing-title').with(
          {
            'command' => "podman network create testing-title --driver bridge --label test 'ing' --label test2 'ing2'",
          },
        )
      end
    end

    context 'with subnet set to valid testing' do
      let(:params) { { subnet: 'testing' } }

      it do
        is_expected.to contain_exec('podman_create_network_testing-title').with(
          {
            'command' => 'podman network create testing-title --driver bridge --subnet testing',
          },
        )
      end
    end

    context 'with ipv6 set to valid true' do
      let(:params) { { ipv6: true } }

      it do
        is_expected.to contain_exec('podman_create_network_testing-title').with(
          {
            'command' => 'podman network create testing-title --driver bridge --ipv6',
          },
        )
      end
    end

    context 'with user set to valid testing' do
      let(:params) { { user: 'testing' } }
      let(:pre_condition) do
        "include podman
         ensure_resource('podman::rootless', 'testing', {})
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

      it do
        is_expected.to contain_exec('podman_create_network_testing-title').with(
          {
            'user'        => 'testing',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'require'     => ['Podman::Rootless[testing]', 'Service[podman systemd-logind]'],
          },
        )
      end

      # only here to reach 100% resource coverage
      it { is_expected.to contain_exec('loginctl_linger_testing') }            # from podman::rootless
      it { is_expected.to contain_exec('start_testing.slice') }                # from podman::rootless
      it { is_expected.to contain_file('/home/testing/.config') }              # from podman::rootless
      it { is_expected.to contain_file('/home/testing/.config/systemd') }      # from podman::rootless
      it { is_expected.to contain_file('/home/testing/.config/systemd/user') } # from podman::rootless
    end
  end
end
