require 'spec_helper'

describe 'podman::pod' do
  let(:title) { 'testing-title' }

  on_supported_os.each do |os, os_facts|
    context "on #{os} with defaults for all parameters" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_exec('create_pod_testing-title').only_with(
          {
            'command'  => "podman pod create  --name 'testing-title'",
            'unless'   => 'podman pod exists testing-title',
            'path'     => '/sbin:/usr/sbin:/bin:/usr/bin',
            'provider' => 'shell',
          },
        )
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
        is_expected.to contain_exec('remove_pod_testing-title').only_with(
          {
            'command'  => 'podman pod rm testing-title',
            'unless'   => 'podman pod exists testing-title; test $? -eq 1',
            'path'     => '/sbin:/usr/sbin:/bin:/usr/bin',
            'provider' => 'shell',
          },
        )
      end
    end

    context 'with ensure set to valid absent when user is set to valid dummy' do
      let(:params) { { ensure: 'absent', user: 'dummy' } }
      let(:pre_condition) do
        "ensure_resource('podman::rootless', 'dummy', {})
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
        is_expected.to contain_exec('remove_pod_testing-title').only_with(
          {
            'command'     => 'podman pod rm testing-title',
            'unless'      => 'podman pod exists testing-title; test $? -eq 1',
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/dummy', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/dummy',
            'provider'    => 'shell',
            'user'        => 'dummy',
            'require'     => ['Podman::Rootless[dummy]', 'Service[podman systemd-logind]'],
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
      it { is_expected.to contain_class('podman') }                          # from podman::rootless
      it { is_expected.to contain_file('/etc/containers/nodocker') }         # from podman
      it { is_expected.to contain_package('buildah') }                       # from podman
      it { is_expected.to contain_package('podman-compose') }                # from podman
      it { is_expected.to contain_package('podman-docker') }                 # from podman
      it { is_expected.to contain_package('podman') }                        # from podman
      it { is_expected.to contain_package('skopeo') }                        # from podman
      if os_facts[:os]['family'] == 'Archlinux'
        it { is_expected.to contain_package('systemd') }                     # from podman
      else
        it { is_expected.to contain_package('systemd-container') }           # from podman
      end
      if os_facts[:os]['selinux']['enabled'] == true
        it { is_expected.to contain_selboolean('container_manage_cgroup') }  # from podman
      end
      it { is_expected.to contain_service('podman.socket') }                 # from podman
    end

    context 'with flags set to valid hash' do
      let(:params) { { flags: { test1: ['value1'], test2: 'value2' } } }

      it do
        is_expected.to contain_exec('create_pod_testing-title').with(
          {
            'command' => "podman pod create  --name 'testing-title'  --test1 'value1' --test2 'value2'",
          },
        )
      end
    end

    context 'with user set to valid value testing' do
      let(:params) { { user: 'testing' } }
      let(:pre_condition) do
        "ensure_resource('podman::rootless', 'testing', {})
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
        is_expected.to contain_exec('create_pod_testing-title').only_with(
          {
            'command'     => "podman pod create  --name 'testing-title'",
            'unless'      => 'podman pod exists testing-title',
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'provider'    => 'shell',
            'user'        => 'testing',
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
