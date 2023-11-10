require 'spec_helper'

describe 'podman::volume' do
  let(:title) { 'testing-title' }

  on_supported_os.each do |os, os_facts|
    context "on #{os} with defaults for all parameters" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_exec('podman_create_volume_testing-title').only_with(
          {
            'command' => 'podman volume create  testing-title',
            'unless'  => 'podman volume inspect testing-title',
            'path'    => '/sbin:/usr/sbin:/bin:/usr/bin',
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
        is_expected.to contain_exec('podman_remove_volume_testing-title').only_with(
          {
            'command' => 'podman volume rm testing-title',
            'unless'  => 'podman volume inspect testing-title; test $? -ne 0',
            'path'    => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end
    end

    context 'with flags set to valid hash' do
      let(:params) { { flags: { test1: ['242:242'], test2: 'jenkins:/test/ing' } } }

      it do
        is_expected.to contain_exec('podman_create_volume_testing-title').only_with(
          {
            'command' => "podman volume create   --test1 '242:242' --test2 'jenkins:/test/ing' testing-title",
            'unless'  => 'podman volume inspect testing-title',
            'path'    => '/sbin:/usr/sbin:/bin:/usr/bin',
          },
        )
      end
    end

    context 'with user set to valid testing' do
      let(:params) { { user: 'testing' } }
      let(:pre_condition) do
        "# user & file needed by podman::rootless
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
        is_expected.to contain_exec('podman_create_volume_testing-title').only_with(
          {
            'command'     => 'podman volume create  testing-title',
            'unless'      => 'podman volume inspect testing-title',
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
      it { is_expected.to contain_service('podman systemd-logind') }           # from podman::rootless
      it { is_expected.to contain_class('podman') }                            # from podman::rootless
      it { is_expected.to contain_file('/etc/containers/nodocker') }           # from podman
      it { is_expected.to contain_package('buildah') }                         # from podman
      it { is_expected.to contain_package('podman-compose') }                  # from podman
      it { is_expected.to contain_package('podman-docker') }                   # from podman
      it { is_expected.to contain_package('podman') }                          # from podman
      it { is_expected.to contain_package('skopeo') }                          # from podman
      if os_facts[:os]['family'] == 'Archlinux'
        it { is_expected.to contain_package('systemd') }                       # from podman
      else
        it { is_expected.to contain_package('systemd-container') }             # from podman
      end
      if os_facts[:os]['selinux']['enabled'] == true
        it { is_expected.to contain_selboolean('container_manage_cgroup') }    # from podman
      end
      it { is_expected.to contain_service('podman.socket') }                   # from podman
    end

    context 'with user set to valid testing when ensure is set to valid absent' do
      let(:params) { { user: 'testing', ensure: 'absent' } }
      let(:pre_condition) do
        "# user & file needed by podman::rootless
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
        is_expected.to contain_exec('podman_remove_volume_testing-title').only_with(
          {
            'command'     => 'podman volume rm testing-title',
            'unless'      => 'podman volume inspect testing-title; test $? -ne 0',
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'provider'    => 'shell',
            'user'        => 'testing',
            'require'     => ['Podman::Rootless[testing]', 'Service[podman systemd-logind]'],
          },
        )
      end
    end
  end
end
