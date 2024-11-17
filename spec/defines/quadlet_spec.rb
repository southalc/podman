require 'spec_helper'

describe 'podman::quadlet' do
  let(:title) { 'container1' }
  let(:pre_condition) { 'include podman' }
  let(:params) { { 'settings' => { 'Container' => { 'Image' => 'example.com/container1:latest', 'PublishPort' => '8080:8080', } } } }

  on_supported_os.each do |os, os_facts|
    let(:facts) { os_facts }

    context "with root container on #{os} with minimal parameters" do
      let(:facts) do
        super().merge({ 'podman' => { 'version' => '4.4' } })
      end

      it do
        is_expected.to compile
        is_expected.to contain_file('/etc/containers/systemd/container1.container').with(
          {
            'ensure' => 'present',
            'notify' => 'Systemd::Daemon_reload[podman]',
          },
        )
        is_expected.to contain_systemd__daemon_reload('podman')
        is_expected.to contain_service('container1').only_with(
          'ensure' => 'running',
          'require' => 'Systemd::Daemon_reload[podman]',
          'subscribe' => 'File[/etc/containers/systemd/container1.container]',
        )
      end
    end

    context 'with unsupported podman version on #{os}' do
      let(:facts) do
        super().merge({ 'podman' => { 'version' => '3.4.4' } })
      end

      it do
        is_expected.to compile
        is_expected.to contain_notify('quadlet_container1')
        is_expected.to contain_notify('quadlet_container1').only_with(
          'message' => 'This version of podman (3.4.4) does not support quadlets.',
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
      let(:facts) do
        super().merge({ 'podman' => { 'version' => '4.4.0' } })
      end

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
            'notify' => 'Systemd::Daemon_reload[podman]',
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
      let(:facts) do
        super().merge({ 'podman' => { 'version' => '4.4.0' } })
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
      let(:facts) do
        super().merge({ 'podman' => { 'version' => '4.4.0' } })
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
  end
end
