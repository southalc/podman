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

      it { is_expected.to compile.and_raise_error(%r{Either secret or path must be specified}) }
      context 'with secret and path parameter set' do
        let(:params) do
          super().merge(secret: sensitive('tiptop'), path: '/bin/fail')
        end

        it { is_expected.to compile.and_raise_error(%r{Only one of secret or path can be specified}) }
      end
      context 'with secret parameter set' do
        let(:params) do
          super().merge(secret: sensitive('tiptop'))
        end

        it { is_expected.to compile }
        it { is_expected.to contain_podman__subuid('testuser') }
        it { is_expected.to contain_podman__subgid('testuser') }
        it { is_expected.to contain_concat__fragment('subuid_fragment_testuser') }
        it { is_expected.to contain_concat__fragment('subgid_fragment_testuser') }
        it { is_expected.to contain_podman_secret('root_password') }

        it {
          is_expected.to contain_podman_secret('root_password')
            .with_ensure('present')
            .with_secret(sensitive('tiptop'))
            .with_flags({ 'label' => 'puppet_resource_flags=e30=' })
        }
      end
      context 'with path parameter set' do
        let(:params) do
          super().merge(path: '/tmp/my_root')
        end

        it { is_expected.to compile }
        it {
          is_expected.to contain_podman_secret('root_password')
            .with_ensure('present')
            .with_path('/tmp/my_root')
            .with_flags({ 'label' => 'puppet_resource_flags=e30=' })
        }
        context 'with a label set' do
          let(:params) do
            super().merge(flags: { label: ['trust=this'] })
          end

          it {
            is_expected.to contain_podman_secret('root_password')
              .with_ensure('present')
              .with_path('/tmp/my_root')
              .with_flags({ 'label' => ['trust=this', 'puppet_resource_flags=eydsYWJlbCcgPT4gWyd0cnVzdD10aGlzJ119'] })
          }
        end
      end
    end
  end
end
