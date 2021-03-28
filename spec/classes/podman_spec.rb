require 'spec_helper'

describe 'podman' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          podman_pkg: 'podman',
          skopeo_pkg: 'skopeo',
          podman_docker_pkg: 'podman-docker',
          manage_subuid: false,
          match_subuid_subgid: true,
          file_header: '# FILE MANAGED BY PUPPET',
          nodocker: 'absent',
          subid: {},
          pods: {},
          volumes: {},
          images: {},
          containers: {},
        }
      end

      it { is_expected.to compile }
    end
  end
end
