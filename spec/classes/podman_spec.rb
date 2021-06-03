require 'spec_helper'

describe 'podman' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          podman_pkg: 'podman',
          skopeo_pkg: 'skopeo',
          buildah_pkg: 'buildah',
          buildah_pkg_ensure: 'installed',
          podman_docker_pkg: 'podman-docker',
          podman_docker_pkg_ensure: 'installed',
          manage_subuid: true,
        }
      end
      let(:pre_condition) do
        'User { "user1":
          uid  => 10001,
          gid  => 10001,
          home => "/home/user1",
        }
        User { "user2":
          uid  => 10002,
          gid  => 10002,
          home => "/home/user2",
        }'
      end

      it { is_expected.to contain_class('podman::install') }
      it { is_expected.to compile }
    end
  end
end
