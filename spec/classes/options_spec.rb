require 'spec_helper'

describe 'podman::options' do
  let(:pre_condition) { 'include podman' }

  on_supported_os.each do |os, os_facts|
    context "on #{os} with defaults for all parameters" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it { is_expected.to contain_class('podman::options') }
      it { is_expected.to have_ini_setting_resource_count(0) }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_class('podman') }                         # from pre_condition
      it { is_expected.to contain_class('podman::install') }                # from podman
      it { is_expected.to contain_class('podman::service') }                # from podman
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

    context 'when podman::storage_options is set to valid hash' do
      let(:pre_condition) { 'class { "podman": storage_options => { testing1 => { option1 => "value1", option2 => "value2" }, testing2 => { option3 => "value3" } } }' }

      it do
        is_expected.to contain_ini_setting('/etc/containers/storage.conf [testing1] option1').only_with(
          {
            'section'  => 'testing1',
            'setting'  => 'option1',
            'value'    => 'value1',
            'ensure'   => 'present',
            'path'     => '/etc/containers/storage.conf',
          },
        )
      end

      it do
        is_expected.to contain_ini_setting('/etc/containers/storage.conf [testing1] option2').only_with(
          {
            'section'  => 'testing1',
            'setting'  => 'option2',
            'value'    => 'value2',
            'ensure'   => 'present',
            'path'     => '/etc/containers/storage.conf',
          },
        )
      end

      it do
        is_expected.to contain_ini_setting('/etc/containers/storage.conf [testing2] option3').only_with(
          {
            'section'  => 'testing2',
            'setting'  => 'option3',
            'value'    => 'value3',
            'ensure'   => 'present',
            'path'     => '/etc/containers/storage.conf',
          },
        )
      end
    end

    context 'when podman::containers_options is set to valid hash' do
      let(:pre_condition) { 'class { "podman": containers_options => { testing1 => { option1 => "value1", option2 => "value2" }, testing2 => { option3 => "value3" } } }' }

      it do
        is_expected.to contain_ini_setting('/etc/containers/containers.conf [testing1] option1').only_with(
          {
            'section'  => 'testing1',
            'setting'  => 'option1',
            'value'    => 'value1',
            'ensure'   => 'present',
            'path'     => '/etc/containers/containers.conf',
          },
        )
      end

      it do
        is_expected.to contain_ini_setting('/etc/containers/containers.conf [testing1] option2').only_with(
          {
            'section'  => 'testing1',
            'setting'  => 'option2',
            'value'    => 'value2',
            'ensure'   => 'present',
            'path'     => '/etc/containers/containers.conf',
          },
        )
      end

      it do
        is_expected.to contain_ini_setting('/etc/containers/containers.conf [testing2] option3').only_with(
          {
            'section'  => 'testing2',
            'setting'  => 'option3',
            'value'    => 'value3',
            'ensure'   => 'present',
            'path'     => '/etc/containers/containers.conf',
          },
        )
      end
    end
  end
end
