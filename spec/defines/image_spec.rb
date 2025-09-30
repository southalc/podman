require 'spec_helper'

describe 'podman::image' do
  let(:title) { 'title' }
  let(:pre_condition) { 'include podman' }

  on_supported_os.each do |os, os_facts|
    context "on #{os} with defaults for all parameters and image set to valid value" do
      let(:facts) { os_facts }
      let(:params) { { image: 'image:test' } }

      it { is_expected.to compile }
      it { is_expected.to contain_class('podman::install') }

      it do
        is_expected.to contain_exec('pull_image_title').only_with(
          {
            'command'     => 'podman image pull  image:test',
            'unless'      => 'podman image exists image:test',
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => [],
          },
        )
      end

      # only here to reach 100% resource coverage
      it { is_expected.to contain_class('podman') }                       # from pre_condition
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
      let(:params) { { ensure: 'absent', image: 'image:test' } }

      it do
        is_expected.to contain_exec('remove_image_title').only_with(
          {
            'command'     => 'podman rmi image:test',
            'onlyif'      => 'podman image exists image:test',
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => [],
          },
        )
      end
    end

    context 'with ensure set to valid absent when user is set to valid dummy' do
      let(:params) { { ensure: 'absent', user: 'dummy', image: 'image:test' } }
      let(:pre_condition) do
        "include podman
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

      it { is_expected.to contain_podman__rootless('dummy').only_with({}) }

      it do
        is_expected.to contain_exec('remove_image_title').only_with(
          {
            'command'     => 'podman rmi image:test',
            'onlyif'      => 'podman image exists image:test',
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/dummy', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/dummy',
            'provider'    => 'shell',
            'user'        => 'dummy',
            'require'     => ['Podman::Rootless[dummy]'],
          },
        )
      end

      # only here to reach 100% resource coverage
      it { is_expected.to contain_podman__rootless('dummy') }
      it { is_expected.to contain_loginctl_user('dummy') }                   # from podman::rootless
      it { is_expected.to contain_exec('start_dummy.slice') }                # from podman::rootless
      it { is_expected.to contain_file('/home/dummy/.config') }              # from podman::rootless
      it { is_expected.to contain_file('/home/dummy/.config/systemd') }      # from podman::rootless
      it { is_expected.to contain_file('/home/dummy/.config/systemd/user') } # from podman::rootless
    end

    context 'with ensure set to valid present when user is set to valid dummy' do
      let(:params) { { ensure: 'present', user: 'dummy', image: 'image:test' } }
      let(:pre_condition) do
        "include podman
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

      it { is_expected.to contain_podman__rootless('dummy').only_with({}) }

      it do
        is_expected.to contain_exec('pull_image_title').only_with(
          {
            'command'     => 'podman image pull  image:test',
            'unless'      => 'podman image exists image:test',
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/dummy', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/dummy',
            'provider'    => 'shell',
            'user'        => 'dummy',
            'require'     => ['Podman::Rootless[dummy]'],
          },
        )
      end
    end

    context 'with flags set to valid hash' do
      let(:params) { { flags: { publish: ['242:242'], volume: 'jenkins:/test/ing' }, image: 'image:test' } }

      it do
        is_expected.to contain_exec('pull_image_title').with(
          {
            'command' => "podman image pull   --publish '242:242' --volume 'jenkins:/test/ing' image:test",
          },
        )
      end
    end

    context 'with flags set to valid hash when ensure is set to valid absent' do
      let(:params) { { flags: { publish: ['242:242'], volume: 'jenkins:/test/ing' }, ensure: 'absent', image: 'image:test' } }

      it do
        is_expected.to contain_exec('remove_image_title').with(
          {
            'command' => 'podman rmi image:test',
          },
        )
      end
    end

    context 'with user set to valid testing' do
      let(:params) { { user: 'testing', image: 'image:test' } }
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
        is_expected.to contain_exec('pull_image_title').only_with(
          {
            'command'     => 'podman image pull  image:test',
            'unless'      => 'podman image exists image:test',
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'provider'    => 'shell',
            'user'        => 'testing',
            'require'     => ['Podman::Rootless[testing]'],
          },
        )
      end

      # only here to reach 100% resource coverage
      it { is_expected.to contain_podman__rootless('testing') }
      it { is_expected.to contain_loginctl_user('testing') }                   # from podman::rootless
      it { is_expected.to contain_exec('start_testing.slice') }                # from podman::rootless
      it { is_expected.to contain_file('/home/testing/.config') }              # from podman::rootless
      it { is_expected.to contain_file('/home/testing/.config/systemd') }      # from podman::rootless
      it { is_expected.to contain_file('/home/testing/.config/systemd/user') } # from podman::rootless
    end

    context 'with user set to valid testing when ensure is set to valid absent' do
      let(:params) { { user: 'testing', ensure: 'absent', image: 'image:test' } }
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
        is_expected.to contain_exec('remove_image_title').only_with(
          {
            'command'     => 'podman rmi image:test',
            'onlyif'      => 'podman image exists image:test',
            'path'        => '/sbin:/usr/sbin:/bin:/usr/bin',
            'environment' => ['HOME=/home/testing', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'cwd'         => '/home/testing',
            'provider'    => 'shell',
            'user'        => 'testing',
            'require'     => ['Podman::Rootless[testing]'],
          },
        )
      end
    end

    context 'with exec_env set to valid [TEST=/test/ing]' do
      let(:params) { { exec_env: ['TEST=/test/ing'], image: 'image:test' } }

      it do
        is_expected.to contain_exec('pull_image_title').with(
          {
            'environment' => ['TEST=/test/ing'],
          },
        )
      end
    end

    context 'with exec_env set to valid [TEST=/test/ing] when user is set to valid dummy' do
      let(:params) { { exec_env: ['TEST=/test/ing'], user: 'dummy', image: 'image:test' } }
      let(:pre_condition) do
        "include podman
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
        is_expected.to contain_exec('pull_image_title').with(
          {
            'environment' => ['HOME=/home/dummy', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus', 'TEST=/test/ing'],
          },
        )
      end
    end
  end
end
