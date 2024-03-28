require 'spec_helper'

describe 'podman::manage_container' do
  let(:title) { 'centos.container' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with a simple centos container image' do
        let(:params) do
          {
            ensure: 'present',
          unit_entry: {
            'Description' => 'Simple centos container',
          },
          service_entry: {
            'TimeoutStartSec' => '900',
          },
          container_entry: {
            'Image' => 'quay.io/centos/centos:latest',
            'Exec' => 'sh -c "sleep inf"',
          },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('podman') }
        it {
          is_expected.to contain_file('/etc/containers/systemd/centos.container')
            .with_ensure('present')
            .with_owner('root')
            .with_group('root')
            .with_mode('0444')
            .with_content(%r{^\[Unit\]$})
            .with_content(%r{^Description=Simple centos container$})
            .with_content(%r{^\[Service\]$})
            .with_content(%r{^TimeoutStartSec=900})
            .with_content(%r{^\[Container\]$})
            .with_content(%r{^Image=quay.io/centos/centos:latest$})
            .with_content(%r{^Exec=sh -c "sleep inf"$})
        }
        it { is_expected.to contain_systemd__daemon_reload('centos.container') }
        it { is_expected.not_to contain_service('centos.container') }
        it { is_expected.not_to contain_service('centos.service') }

        context 'with the container absent' do
          let(:params) do
            super().merge({ ensure: 'absent' })
          end

          it { is_expected.to contain_file('/etc/containers/systemd/centos.container').with_ensure('absent') }
          it { is_expected.to contain_systemd__daemon_reload('centos.container') }
        end

        context 'with daemon_reload false' do
          let(:params) do
            super().merge({ daemon_reload: false })
          end

          it { is_expected.not_to contain_systemd__daemon_reload('centos.container') }
        end

        context 'with the service active' do
          let(:params) do
            super().merge({ active: true })
          end

          it { is_expected.to contain_service('centos.service').with_ensure(true) }
        end
      end
    end
  end
end
