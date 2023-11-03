require 'spec_helper'

describe 'podman::rootless' do
  let(:title) { 'testing-title' }
  let(:pre_condition) do
    "include podman
     # user & file needed by podman::rootless
     user { 'testing-title':
       ensure  => 'present',
       gid     => 1111,
       home    => '/home/testing-title',
       uid     => 3333,
     }
     file { '/home/testing-title': }
    "
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os} with defaults for all parameters" do
      let(:facts) { os_facts }

      it { is_expected.to compile }

      it do
        is_expected.to contain_exec('loginctl_linger_testing-title').only_with(
          {
            'path'     => '/sbin:/usr/sbin:/bin:/usr/bin',
            'command'  => 'loginctl enable-linger testing-title',
            'provider' => 'shell',
            'unless'   => "test $(loginctl show-user testing-title --property=Linger) = 'Linger=yes'",
            'require'  => 'User[testing-title]',
            'notify'   => 'Service[podman systemd-logind]',
          },
        )
      end

      it do
        is_expected.to contain_service('podman systemd-logind').only_with(
          {
            'name'   => 'systemd-logind.service',
            'ensure' => 'running',
          },
        )
      end

      it do
        is_expected.to contain_file('/home/testing-title/.config').only_with(
          {
            'ensure'  => 'directory',
            'owner'   => 'testing-title',
            'group'   => '1111',
            'mode'    => '0700',
            'require' => 'File[/home/testing-title]',
          },
        )
      end

      it do
        is_expected.to contain_file('/home/testing-title/.config/systemd').only_with(
          {
            'ensure'  => 'directory',
            'owner'   => 'testing-title',
            'group'   => '1111',
            'mode'    => '0700',
            'require' => 'File[/home/testing-title]',
          },
        )
      end

      it do
        is_expected.to contain_file('/home/testing-title/.config/systemd/user').only_with(
          {
            'ensure'  => 'directory',
            'owner'   => 'testing-title',
            'group'   => '1111',
            'mode'    => '0700',
            'require' => 'File[/home/testing-title]',
          },
        )
      end

      it do
        is_expected.to contain_exec('start_testing-title.slice').only_with(
          {
            'path'    => os_facts[:path],
            'command' => "machinectl shell testing-title@.host '/bin/true'",
            'unless'  => 'systemctl is-active user-3333.slice',
            'require' => ['Exec[loginctl_linger_testing-title]', 'Service[podman systemd-logind]', 'File[/home/testing-title/.config/systemd/user]'],
          },
        )
      end

      # only here to reach 100% resource coverage
      it { is_expected.to contain_class('podman::install') }                # from podman
      it { is_expected.to contain_class('podman::options') }                # from podman
      it { is_expected.to contain_class('podman::service') }                # from podman
      it { is_expected.to contain_class('podman') }                         # from pre_condition
      it { is_expected.to contain_file('/etc/containers/nodocker') }        # from podman::install
      it { is_expected.to contain_package('buildah') }                      # from podman::install
      it { is_expected.to contain_package('podman-compose') }               # from podman::install
      it { is_expected.to contain_package('podman-docker') }                # from podman::install
      it { is_expected.to contain_package('podman') }                       # from podman::install
      it { is_expected.to contain_package('skopeo') }                       # from podman::install
      if os_facts[:os]['family'] == 'Archlinux'
        it { is_expected.to contain_package('systemd') }                    # from podman::install
      else
        it { is_expected.to contain_package('systemd-container') }          # from podman::install
      end
      if os_facts[:os]['selinux']['enabled'] == true
        it { is_expected.to contain_selboolean('container_manage_cgroup') } # from podman::install
      end
      it { is_expected.to contain_service('podman.socket') }                # from podman::service
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

    context 'with podman::enable_api_socket is set to valid true' do
      let(:facts) { os_facts }
      let(:pre_condition) do
        "class { 'podman':
           enable_api_socket => true,
         }
         # user & file needed by podman::rootless
         user { 'testing-title':
           ensure  => 'present',
           gid     => 1111,
           home    => '/home/testing-title',
           uid     => 3333,
         }
         file { '/home/testing-title': }
        "
      end

      it do
        is_expected.to contain_exec('podman rootless api socket testing-title').only_with(
          {
            'command'     => 'systemctl --user enable --now podman.socket',
            'path'        => os_facts[:path],
            'user'        => 'testing-title',
            'environment' => ['HOME=/home/testing-title', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'unless'      => 'systemctl --user status podman.socket',
            'require'     => ['Exec[loginctl_linger_testing-title]', 'Exec[start_testing-title.slice]'],
          },
        )
      end
    end
  end
end
