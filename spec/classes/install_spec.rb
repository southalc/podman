require 'spec_helper'

describe 'podman::install' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:params) do
        {
          #podman_pkg: 'podman',
          #skopeo_pkg: 'skopeo',
          #podman_docker_pkg: 'podman-docker',
          manage_subuid: true,
          file_header: '# FILE MANAGED BY PUPPET',
          match_subuid_subgid: true,
          subid: {
            testuser: {
              subuid: 5_000_000,
              count: 1000,
            },
          },
          nodocker: 'file',
        }
      end

      it { is_expected.to compile }
    end
  end
end
