require 'spec_helper'

describe 'podman::service' do
  let(:pre_condition) { 'include podman' }

  on_supported_os.each do |os, os_facts|
    context "on #{os} with defaults for all parameters" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it { is_expected.to contain_class('podman::install') }

      it do
        is_expected.to contain_service('podman.socket').only_with(
          {
            'ensure' => 'stopped',
            'enable' => false,
          },
        )
      end

      # only here to reach 100% resource coverage
      it { is_expected.to contain_class('podman') }                         # from pre_condition
      it { is_expected.to contain_class('podman::options') }                # from podman
      it { is_expected.to contain_file('/etc/containers/nodocker') }        # from podman::install
      it { is_expected.to contain_package('podman') }                       # from podman::install
      it { is_expected.to contain_package('skopeo') }                       # from podman::install
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

    context 'when podman::enable_api_socket is set to valid true' do
      let(:pre_condition) { 'class { "podman": enable_api_socket => true }' }

      it do
        is_expected.to contain_service('podman.socket').only_with(
          {
            'ensure' => 'running',
            'enable' => true,
          },
        )
      end
    end
  end
end
