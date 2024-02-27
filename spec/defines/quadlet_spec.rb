# frozen_string_literal: true

require 'spec_helper'

describe 'podman::quadlet' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with a simple centos container image' do
        let(:title) { 'centos.container' }
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
              'PublishPort' => [1234, '123.1.1.1:100:102'],
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

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
            .with_content(%r{^PublishPort=1234$})
            .with_content(%r{^PublishPort=123.1.1.1:100:102$})
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

        context 'with the service active' do
          let(:params) do
            super().merge({ active: true })
          end

          it { is_expected.to contain_service('centos.service').with_ensure(true) }
        end

        context 'with a user set' do
          let(:pre_condition) do
            <<~PUPPET
            user{'steve':
              ensure => present,
              uid    => 1000,
              gid    => 1000,
              home   => '/var/lib/steve',
            }
            file{'/var/lib/steve':
              ensure => directory,
              owner  => steve,
              group  => 1000,
              mode   => '0644',
            }
            PUPPET
          end
          let(:params) do
            super().merge({
                            user: 'steve',
                          })
          end

          it { is_expected.to compile.with_all_deps }
          it { is_expected.to contain_podman__rootless('steve') }
          context 'with active true' do
            let(:params) do
              super().merge({
                              active: true,
                            })
            end

            it { is_expected.to contain_exec('start-centos.container-steve') }
            it {
              is_expected.to contain_exec('start-centos.container-steve').with(
              {
                command: ['systemd-run', '--pipe', '--wait', '--user', '--machine', 'steve@.host', 'systemctl', '--user', 'start', 'centos.service'],
                unless: [['systemd-run', '--pipe', '--wait', '--user', '--machine', 'steve@.host', 'systemctl', '--user', 'is-active', 'centos.service']],
              },
            )
            }
          end
        end
      end
      context 'with a simple pod quadlet' do
        let(:title) { 'mypod.pod' }
        let(:params) do
          {
            ensure: 'present',
            unit_entry: {
              'Description' => 'Simple Pod',
            },
            service_entry: {
              'TimeoutStartSec' => '900',
            },
            pod_entry: {
              'Network' => 'host',
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/containers/systemd/mypod.pod')
            .with_ensure('present')
            .with_owner('root')
            .with_group('root')
            .with_mode('0444')
            .with_content(%r{^\[Unit\]$})
            .with_content(%r{^Description=Simple Pod$})
            .with_content(%r{^\[Pod\]$})
            .with_content(%r{^Network=host$})
        }
        context 'with the pod active' do
          let(:params) do
            super().merge({ active: true })
          end

          it { is_expected.to contain_service('mypod-pod.service') }
        end
      end
      context 'with a simple volume quadlet' do
        let(:title) { 'myvolume.volume' }
        let(:params) do
          {
            ensure: 'present',
            unit_entry: {
              'Description' => 'Simple Volume',
            },
            service_entry: {
              'TimeoutStartSec' => '900',
            },
            volume_entry: {
              'Driver' => 'image',
            },
          }
        end

        it { is_expected.to compile.with_all_deps }

        it {
          is_expected.to contain_file('/etc/containers/systemd/myvolume.volume')
            .with_ensure('present')
            .with_owner('root')
            .with_group('root')
            .with_mode('0444')
            .with_content(%r{^\[Unit\]$})
            .with_content(%r{^Description=Simple Volume$})
            .with_content(%r{^\[Volume\]$})
            .with_content(%r{^Driver=image$})
        }
        context 'with the service active' do
          let(:params) do
            super().merge({ active: true })
          end

          it { is_expected.to contain_service('myvolume-volume.service') }
        end
      end
    end
  end
end
