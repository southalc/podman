require 'spec_helper'

describe 'podman::pod' do
  let(:title) { 'testpod' }
  let(:params) do
    {
      flags: {
        label: 'app=wordpress',
      },
    }
  end

  let(:pre_condition) do
    'class {"::podman::install":
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

      it { is_expected.to compile }
    end
  end
end
