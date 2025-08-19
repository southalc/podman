require 'spec_helper'

describe 'podman::install' do
  let(:pre_condition) { 'include podman' }

  on_supported_os.each do |os, os_facts|
    context "on #{os} with defaults for all parameters" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it { is_expected.not_to contain_package('buildah') }
      it { is_expected.not_to contain_package('podman-compose') }
      it { is_expected.not_to contain_package('podman-docker') }
      it { is_expected.to contain_package('podman').with_ensure('installed') }
      it { is_expected.to contain_package('skopeo').with_ensure('installed') }

      if os_facts[:os]['family'] == 'Archlinux'
        it { is_expected.not_to contain_package('systemd') }
      else
        it { is_expected.not_to contain_package('systemd-container') }
      end

      if os_facts[:os]['selinux']['enabled'] == true
        it do
          is_expected.to contain_selboolean('container_manage_cgroup').only_with(
            {
              'persistent' => true,
              'value'      => 'on',
              'require'    => 'Package[podman]',
            },
          )
        end
      end

      it do
        is_expected.to contain_file('/etc/containers/nodocker').only_with(
          {
            'ensure'  => 'absent',
            'group'   => 'root',
            'owner'   => 'root',
            'mode'    => '0644',
            'require' => 'Package[podman]',
          },
        )
      end

      # only here to reach 100% resource coverage
      it { is_expected.to contain_class('podman') }          # from pre_condition
      it { is_expected.to contain_class('podman::options') } # from podman
      it { is_expected.to contain_class('podman::service') } # from podman
      it { is_expected.to contain_service('podman.socket') } # from podman::service
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

    context 'when podman::podman_pkg is set to valid testing' do
      let(:pre_condition) { 'class { "podman": podman_pkg => "testing" }' }

      it { is_expected.to contain_package('testing') }
    end

    context 'when podman::skopeo_pkg is set to valid testing' do
      let(:pre_condition) { 'class { "podman": skopeo_pkg => "testing" }' }

      it { is_expected.to contain_package('testing') }
    end

    context 'when podman::buildah_pkg is set to valid testing' do
      let(:pre_condition) { 'class { "podman": buildah_pkg => "testing", buildah_pkg_ensure => "installed" }' }

      it { is_expected.to contain_package('testing') }
    end

    context 'when podman::buildah_pkg_ensure is set to valid installed' do
      let(:pre_condition) { 'class { "podman": buildah_pkg_ensure => "installed" }' }

      it { is_expected.to contain_package('buildah').with_ensure('installed') }
    end

    context 'when podman::podman_docker_pkg is set to valid testing' do
      let(:pre_condition) { 'class { "podman": podman_docker_pkg => "testing", podman_docker_pkg_ensure => "installed" }' }

      it { is_expected.to contain_package('testing') }
    end

    context 'when podman::podman_docker_pkg_ensure is set to valid absent' do
      let(:pre_condition) { 'class { "podman": podman_docker_pkg_ensure => "absent" }' }

      it { is_expected.to contain_package('podman-docker').with_ensure('absent') }
    end

    context 'when podman::compose_pkg is set to valid testing' do
      let(:pre_condition) { 'class { "podman": compose_pkg => "testing", compose_pkg_ensure => "installed" }' }

      it { is_expected.to contain_package('testing') }
    end

    context 'when podman::compose_pkg_ensure is set to valid installed' do
      let(:pre_condition) { 'class { "podman": compose_pkg_ensure => "installed" }' }

      it { is_expected.to contain_package('podman-compose').with_ensure('installed') }
    end

    context 'when podman::machinectl_pkg is set to valid testing' do
      let(:pre_condition) { 'class { "podman": machinectl_pkg => "testing", machinectl_pkg_ensure => "installed" }' }

      it { is_expected.to contain_package('testing') }
    end

    context 'when podman::machinectl_pkg_ensure is set to valid absent' do
      let(:pre_condition) { 'class { "podman": machinectl_pkg_ensure => "absent" }' }

      it { is_expected.to contain_package('systemd-container').with_ensure('absent') }
    end

    context 'when podman::manage_subuid is set to valid true' do
      let(:pre_condition) { 'class { "podman": manage_subuid => true }' }

      it do
        is_expected.to contain_concat('/etc/subuid').with(
          {
            'owner'          => 'root',
            'group'          => 'root',
            'mode'           => '0644',
            'order'          => 'alpha',
            'ensure_newline' => true,
          },
        )
      end

      it do
        is_expected.to contain_concat('/etc/subgid').with(
          {
            'owner'          => 'root',
            'group'          => 'root',
            'mode'           => '0644',
            'order'          => 'alpha',
            'ensure_newline' => true,
          },
        )
      end

      it do
        is_expected.to contain_concat_fragment('subuid_header').only_with(
          {
            'target'  => '/etc/subuid',
            'order'   => '1',
            'content' => '# FILE MANAGED BY PUPPET',
          },
        )
      end

      it do
        is_expected.to contain_concat_fragment('subgid_header').only_with(
          {
            'target'  => '/etc/subgid',
            'order'   => '1',
            'content' => '# FILE MANAGED BY PUPPET',
          },
        )
      end

      it { is_expected.to have_podman__subuid_resource_count(0) }
      it { is_expected.to have_podman__subgid_resource_count(0) }
    end

    context 'when podman::manage_subuid is set to valid true when podman::subid is a valid hash' do
      let(:pre_condition) { 'class { "podman": manage_subuid => true, subid => { dummy => { subuid => 242, count => 1 } } }' }

      it do
        is_expected.to contain_podman__subuid('dummy').only_with(
          {
            'subuid' => 242,
            'count'  => 1,
            'order'  => 10,
          },
        )
      end

      it do
        is_expected.to contain_podman__subgid('dummy').only_with(
          {
            'subgid' => 242,
            'count'  => 1,
            'order'  => 10,
          },
        )
      end

      it { is_expected.to have_podman__subuid_resource_count(1) }
      it { is_expected.to have_podman__subgid_resource_count(1) }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_concat__fragment('subgid_fragment_dummy') } # from podman::subgid
      it { is_expected.to contain_concat__fragment('subuid_fragment_dummy') } # from podman::subuid
    end

    context 'when podman::manage_subuid is set to valid true when match_subuid_subgid is false and podman::subid is a valid hash' do
      let(:pre_condition) { 'class { "podman": manage_subuid => true, match_subuid_subgid => false, subid => { dummy => { subuid => 242, count => 1 } } }' }

      it { is_expected.to have_podman__subuid_resource_count(0) }
      it { is_expected.to have_podman__subgid_resource_count(0) }
    end
  end
end
