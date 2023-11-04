require 'spec_helper'

describe 'podman::secret' do
  let(:title) { 'root_password' }
  let(:params) do
    {
      ensure: 'present',
    }
  end
  let(:pre_condition) do
    'user {"testuser":
      ensure        => "present",
      home          => "/home/testuser",
      uid           => 5000,
      gid           => 5000,
      managehome    => true,
    }
    file {"/home/testuser":
      ensure => "directory",
    }
    class {"podman":
      podman_pkg               => "podman",
      skopeo_pkg               => "skopeo",
      buildah_pkg              => "buildah",
      buildah_pkg_ensure       => "installed",
      podman_docker_pkg_ensure => "installed",
      podman_docker_pkg        => "podman-docker",
      manage_subuid            => true,
      file_header              => " FILE MANAGED BY PUPPET",
      match_subuid_subgid      => true,
      subid                    => {
                                    testuser => {
                                      subuid => 5000000,
                                      count  => 1000,
                                    },
                                  },
      nodocker                 => "file",
    }'
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.and_raise_error(%r{One of the parameters path or secret}) }
      context 'with secret and path parameter set' do
        let(:params) do
          super().merge(secret: sensitive('tiptop'), path: '/bin/fail')
        end

        it { is_expected.to compile.and_raise_error(%r{Only one of the parameters path or secret}) }
      end
      context 'with secret parameter set' do
        let(:params) do
          super().merge(secret: sensitive('tiptop'))
        end

        it { is_expected.to compile }
        it { is_expected.to contain_exec('create_secret_root_password') }
        it {
          is_expected.to contain_exec('create_secret_root_password')
            .with_command(sensitive("printf 'tiptop' | podman secret create --label 'puppet_resource_flags=e30=' root_password -\n"))
            .with_unless("test \"\$(podman secret inspect root_password  --format ''{{.Spec.Labels.puppet_resource_flags}}'')\" = \"e30=\"")
        }
      end
      context 'with path parameter set' do
        let(:params) do
          super().merge(path: '/tmp/my_root')
        end

        it { is_expected.to compile }
        it {
          is_expected.to contain_exec('create_secret_root_password')
            .with_command("podman secret create --label 'puppet_resource_flags=e30=' root_password /tmp/my_root")
        }
        context 'with a label set' do
          let(:params) do
            super().merge(flags: { label: ['trust=this'] })
          end

          it {
            is_expected.to contain_exec('create_secret_root_password')
              .with_command("podman secret create  --label 'trust=this' --label 'puppet_resource_flags=eydsYWJlbCcgPT4gWyd0cnVzdD10aGlzJ119' root_password /tmp/my_root")
              .with_unless("test \"\$(podman secret inspect root_password  --format ''{{.Spec.Labels.puppet_resource_flags}}'')\" = \"eydsYWJlbCcgPT4gWyd0cnVzdD10aGlzJ119\"")
          }
        end
      end
    end
  end
end
