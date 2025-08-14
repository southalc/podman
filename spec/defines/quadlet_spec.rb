require 'spec_helper'

describe 'podman::quadlet' do
  let(:title) { 'container1' }
  let(:pre_condition) { 'include podman' }
  let(:params) { { 'settings' => { 'Container' => { 'Image' => 'example.com/container1:latest', 'PublishPort' => '8080:8080', } } } }

  on_supported_os.each do |os, os_facts|
    let(:facts) { os_facts }

    context "with root container on #{os} with minimal parameters" do
      it do
        is_expected.to compile
        is_expected.to contain_file('/etc/containers/systemd/container1.container').with(
          {
            'ensure' => 'present',
            'notify' => 'Systemd::Daemon_reload[container1]',
          },
        )
        is_expected.to contain_systemd__daemon_reload('container1')
        is_expected.to contain_service('container1').only_with(
          'ensure' => 'running',
          'require' => 'Systemd::Daemon_reload[container1]',
          'subscribe' => 'File[/etc/containers/systemd/container1.container]',
        )
      end
    end

    context "with root container on #{os} with service_ensure => 'running'" do
      let(:params) { { 'service_ensure' => 'running', 'settings' => { 'Container' => { 'Image' => 'example.com/container1:latest', 'PublishPort' => '8080:8080', } } } }

      it do
        is_expected.to compile
        is_expected.to contain_file('/etc/containers/systemd/container1.container').with(
          {
            'ensure' => 'present',
            'notify' => 'Systemd::Daemon_reload[container1]',
          },
        )
        is_expected.to contain_systemd__daemon_reload('container1')
        is_expected.to contain_service('container1').only_with(
          'ensure' => 'running',
          'require' => 'Systemd::Daemon_reload[container1]',
          'subscribe' => 'File[/etc/containers/systemd/container1.container]',
        )
      end
    end

    context "with root container on #{os} with service_ensure => 'stopped'" do
      let(:params) { { 'service_ensure' => 'stopped', 'settings' => { 'Container' => { 'Image' => 'example.com/container1:latest', 'PublishPort' => '8080:8080', } } } }

      it do
        is_expected.to compile
        is_expected.to contain_file('/etc/containers/systemd/container1.container').with(
          {
            'ensure' => 'present',
            'notify' => 'Systemd::Daemon_reload[container1]',
          },
        )
        is_expected.to contain_systemd__daemon_reload('container1')
        is_expected.to contain_service('container1').only_with(
          'ensure' => 'stopped',
          'require' => 'Systemd::Daemon_reload[container1]',
          'subscribe' => 'File[/etc/containers/systemd/container1.container]',
        )
      end
    end

    context 'with unsupported OS version on #{os}' do
      let(:facts) do
        super().merge({
                        'os' => {
                          'name' => 'Ubuntu',
                          'family' => 'Debian',
                          'release' => { 'full' => '20.04', 'major' => '20' },
                          'selinux' => { 'enabled' => false }
                        }
                      })
      end

      it do
        is_expected.to compile
        is_expected.to contain_notify('quadlet_container1')
        is_expected.to contain_notify('quadlet_container1').only_with(
          'message' => 'Quadlets are not supported on Ubuntu 20.04. Supported: Fedora (all), EL 8+, Ubuntu 24.04+, Debian 13+, Archlinux.',
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

    context 'root container with ensure set to absent' do
      let(:params) { { ensure: 'absent' } }

      it do
        is_expected.to compile
        is_expected.to contain_service('container1').only_with(
          {
            'ensure' => 'stopped',
            'notify' => 'File[/etc/containers/systemd/container1.container]',
          },
        )
        is_expected.to contain_file('/etc/containers/systemd/container1.container').with(
          {
            'ensure' => 'absent',
            'notify' => 'Systemd::Daemon_reload[container1]',
          },
        )
      end
    end

    context 'with user set to valid testing' do
      let(:pre_condition) do
        'include podman
         # user & file needed by podman::rootless
         user { "testing":
           ensure  => "present",
           gid     => 1111,
           home    => "/home/testing",
           uid     => 3333,
         }
         file { "/home/testing": }
        '
      end
      let(:params) do
        super().merge({ 'user' => 'testing' })
      end

      it do
        is_expected.to contain_podman__rootless('testing').only_with({})
        is_expected.to contain_systemd__daemon_reload('podman_rootless_testing')
        is_expected.to contain_file('/etc/containers/systemd/users')
        is_expected.to contain_file('/etc/containers/systemd/users/3333')
        is_expected.to contain_file('/etc/containers/systemd/users/3333/container1.container').with(
          {
            'ensure' => 'present',
            'notify' => 'Systemd::Daemon_reload[podman_rootless_testing]',
            'require' => '[Podman::Rootless[testing]{:name=>"testing"}]',
          },
        )
        is_expected.to contain_systemd__user_service('container1').with(
          {
            'ensure' => true,
            'enable' => true,
            'user' => 'testing',
            'unit' => 'container1.service',
            'require' => 'Systemd::Daemon_reload[podman_rootless_testing]',
            'subscribe' => 'File[/etc/containers/systemd/users/3333/container1.container]',
          },
        )
      end
    end

    context 'with user set to valid testing and service_ensure => running' do
      let(:pre_condition) do
        'include podman
         # user & file needed by podman::rootless
         user { "testing":
           ensure  => "present",
           gid     => 1111,
           home    => "/home/testing",
           uid     => 3333,
         }
         file { "/home/testing": }
        '
      end
      let(:params) do
        super().merge({ 'user' => 'testing', 'service_ensure' => 'running' })
      end

      it do
        is_expected.to contain_podman__rootless('testing').only_with({})
        is_expected.to contain_systemd__daemon_reload('podman_rootless_testing')
        is_expected.to contain_file('/etc/containers/systemd/users')
        is_expected.to contain_file('/etc/containers/systemd/users/3333')
        is_expected.to contain_file('/etc/containers/systemd/users/3333/container1.container').with(
          {
            'ensure' => 'present',
            'notify' => 'Systemd::Daemon_reload[podman_rootless_testing]',
            'require' => '[Podman::Rootless[testing]{:name=>"testing"}]',
          },
        )
        is_expected.to contain_systemd__user_service('container1').with(
          {
            'ensure' => true,
            'enable' => true,
            'user' => 'testing',
            'unit' => 'container1.service',
            'require' => 'Systemd::Daemon_reload[podman_rootless_testing]',
            'subscribe' => 'File[/etc/containers/systemd/users/3333/container1.container]',
          },
        )
      end
    end

    context 'with user set to valid testing and service_ensure => stopped' do
      let(:pre_condition) do
        'include podman
         # user & file needed by podman::rootless
         user { "testing":
           ensure  => "present",
           gid     => 1111,
           home    => "/home/testing",
           uid     => 3333,
         }
         file { "/home/testing": }
        '
      end
      let(:params) do
        super().merge({ 'user' => 'testing', 'service_ensure' => 'stopped' })
      end

      it do
        is_expected.to contain_podman__rootless('testing').only_with({})
        is_expected.to contain_systemd__daemon_reload('podman_rootless_testing')
        is_expected.to contain_file('/etc/containers/systemd/users')
        is_expected.to contain_file('/etc/containers/systemd/users/3333')
        is_expected.to contain_file('/etc/containers/systemd/users/3333/container1.container').with(
          {
            'ensure' => 'present',
            'notify' => 'Systemd::Daemon_reload[podman_rootless_testing]',
            'require' => '[Podman::Rootless[testing]{:name=>"testing"}]',
          },
        )
        is_expected.to contain_systemd__user_service('container1').with(
          {
            'ensure' => false,
            'enable' => true,
            'user' => 'testing',
            'unit' => 'container1.service',
            'require' => 'Systemd::Daemon_reload[podman_rootless_testing]',
            'subscribe' => 'File[/etc/containers/systemd/users/3333/container1.container]',
          },
        )
      end
    end

    context 'with user set to valid testing and ensure set to absent' do
      let(:pre_condition) do
        'include podman
         # user & file needed by podman::rootless
         user { "testing":
           ensure  => "present",
           gid     => 1111,
           home    => "/home/testing",
           uid     => 3333,
         }
         file { "/home/testing": }
        '
      end
      let(:params) do
        super().merge({ 'user' => 'testing', 'ensure' => 'absent' })
      end

      it do
        is_expected.to contain_podman__rootless('testing').only_with({})
        is_expected.to contain_systemd__daemon_reload('podman_rootless_testing')
        is_expected.to contain_file('/etc/containers/systemd/users')
        is_expected.to contain_file('/etc/containers/systemd/users/3333')
        is_expected.to contain_file('/etc/containers/systemd/users/3333/container1.container').with(
          {
            'ensure' => 'absent',
            'notify' => 'Systemd::Daemon_reload[podman_rootless_testing]',
            'require' => '[Podman::Rootless[testing]{:name=>"testing"}]',
          },
        )
        is_expected.to contain_systemd__user_service('container1').with(
          {
            'ensure' => false,
            'enable' => false,
            'user' => 'testing',
            'unit' => 'container1.service',
            'notify' => 'File[/etc/containers/systemd/users/3333/container1.container]',
          },
        )
      end
    end

    context 'with supported Ubuntu version' do
      let(:pre_condition) do
        'include podman
         # user & file needed by podman::rootless
         user { "testing":
           ensure  => "present",
           gid     => 1111,
           home    => "/home/testing",
           uid     => 3333,
         }
         file { "/home/testing": }
        '
      end
      let(:facts) do
        super().merge({
                        'os' => {
                          'name' => 'Ubuntu',
                          'family' => 'Debian',
                          'release' => { 'full' => '24.04', 'major' => '24' },
                          'selinux' => { 'enabled' => false }
                        }
                      })
      end
      let(:params) do
        super().merge({ 'user' => 'testing' })
      end

      it do
        is_expected.to compile
        is_expected.to contain_podman__rootless('testing')
        is_expected.to contain_file('/etc/containers/systemd/users/3333/container1.container')
      end
    end

    context 'with unsupported Debian version' do
      let(:facts) do
        super().merge({
                        'os' => {
                          'name' => 'Debian',
                          'family' => 'Debian',
                          'release' => { 'full' => '12.0', 'major' => '12' },
                          'selinux' => { 'enabled' => false }
                        }
                      })
      end

      it do
        is_expected.to compile
        is_expected.to contain_notify('quadlet_container1')
        is_expected.to contain_notify('quadlet_container1').only_with(
          'message' => 'Quadlets are not supported on Debian 12.0. Supported: Fedora (all), EL 8+, Ubuntu 24.04+, Debian 13+, Archlinux.',
        )
      end
    end

    context 'with supported Fedora' do
      let(:facts) do
        super().merge({
                        'os' => {
                          'name' => 'Fedora',
                          'family' => 'RedHat',
                          'release' => { 'full' => '39', 'major' => '39' },
                          'selinux' => { 'enabled' => true }
                        }
                      })
      end

      it do
        is_expected.to compile
        is_expected.to contain_file('/etc/containers/systemd/container1.container')
        is_expected.to contain_service('container1')
      end
    end

    context 'with supported EL8' do
      let(:facts) do
        super().merge({
                        'os' => {
                          'name' => 'RedHat',
                          'family' => 'RedHat',
                          'release' => { 'full' => '8.9', 'major' => '8' },
                          'selinux' => { 'enabled' => true }
                        }
                      })
      end

      it do
        is_expected.to compile
        is_expected.to contain_file('/etc/containers/systemd/container1.container')
        is_expected.to contain_service('container1')
      end
    end

    context 'with unsupported EL7' do
      let(:facts) do
        super().merge({
                        'os' => {
                          'name' => 'CentOS',
                          'family' => 'RedHat',
                          'release' => { 'full' => '7.9', 'major' => '7' },
                          'selinux' => { 'enabled' => true }
                        }
                      })
      end

      it do
        is_expected.to compile
        is_expected.to contain_notify('quadlet_container1')
        is_expected.to contain_notify('quadlet_container1').only_with(
          'message' => 'Quadlets are not supported on CentOS 7.9. Supported: Fedora (all), EL 8+, Ubuntu 24.04+, Debian 13+, Archlinux.',
        )
      end
    end
  end
end
