require 'spec_helper'

describe 'podman' do
  on_supported_os.each do |os, os_facts|
    context "on #{os} with defaults for all parameters" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
      it { is_expected.to contain_class('podman::install') }
      it { is_expected.to contain_class('podman::options') }
      it { is_expected.to contain_class('podman::service') }
      it { is_expected.to have_package_resource_count(2) }
      it { is_expected.to have_podman__pod_resource_count(0) }
      it { is_expected.to have_podman__volume_resource_count(0) }
      it { is_expected.to have_podman__image_resource_count(0) }
      it { is_expected.to have_podman__container_resource_count(0) }
      it { is_expected.to have_podman__network_resource_count(0) }
      it { is_expected.to have_podman__rootless_resource_count(0) }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_file('/etc/containers/nodocker') }        # from podman::install
      it { is_expected.not_to contain_package('podman-docker') }            # from podman::install
      it { is_expected.to contain_package('podman') }                       # from podman::install
      it { is_expected.to contain_package('skopeo') }                       # from podman::install
      if os_facts[:os]['family'] == 'Archlinux'
        it { is_expected.not_to contain_package('systemd') }                # from podman::install
      else
        it { is_expected.not_to contain_package('systemd-container') }      # from podman::install
      end
      if os_facts[:os]['selinux']['enabled'] == true
        it { is_expected.to contain_selboolean('container_manage_cgroup') } # from podman::install
      end
      it { is_expected.to contain_service('podman.socket') }                # from podman::service
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

    context 'with podman_pkg set to valid testing' do
      let(:params) { { podman_pkg: 'testing' } } # parameter used in podman::install

      it { is_expected.to contain_package('testing') }
    end

    context 'with skopeo_pkg set to valid testing' do
      let(:params) { { skopeo_pkg: 'testing' } } # parameter used in podman::install

      it { is_expected.to contain_package('testing') }
    end

    context 'with buildah_pkg set to valid testing' do
      let(:params) { { buildah_pkg: 'testing', buildah_pkg_ensure: 'installed' } } # parameters used in podman::install

      it { is_expected.to contain_package('testing') }
    end

    context 'with podman_docker_pkg set to valid testing' do
      let(:params) { { podman_docker_pkg: 'testing', podman_docker_pkg_ensure: 'installed' } } # parameters used in podman::install

      it { is_expected.to contain_package('testing') }
    end

    context 'with compose_pkg set to valid testing' do
      let(:params) { { compose_pkg: 'testing', compose_pkg_ensure: 'installed' } } # parameters used in podman::install

      it { is_expected.to contain_package('testing') }
    end

    context 'with machinectl_pkg set to valid testing' do
      let(:params) { { machinectl_pkg: 'testing', machinectl_pkg_ensure: 'installed' } } # parameters used in podman::install

      it { is_expected.to contain_package('testing') }
    end

    context 'with podman_pkg_ensure set to valid installed' do
      let(:params) { { podman_pkg_ensure: 'installed' } } # parameter used in podman::install

      it { is_expected.to contain_package('podman').with_ensure('installed') }
    end

    context 'with podman_pkg_ensure set to valid version 1.0.0' do
      let(:params) { { podman_pkg_ensure: '1.0.0' } } # parameter used in podman::install

      it { is_expected.to contain_package('podman').with_ensure('1.0.0') }
    end

    context 'with buildah_pkg_ensure set to valid installed' do
      let(:params) { { buildah_pkg_ensure: 'installed' } } # parameter used in podman::install

      it { is_expected.to contain_package('buildah').with_ensure('installed') }
    end

    context 'with podman_docker_pkg_ensure set to valid absent' do
      let(:params) { { podman_docker_pkg_ensure: 'absent' } } # parameter used in podman::install

      it { is_expected.to contain_package('podman-docker').with_ensure('absent') }
    end
    context 'with compose_pkg_ensure set to valid installed' do
      let(:params) { { compose_pkg_ensure: 'installed' } } # parameter used in podman::install

      it { is_expected.to contain_package('podman-compose').with_ensure('installed') }
    end
    context 'with compose_pkg_ensure set to valid version 1.0.0' do
      let(:params) { { compose_pkg_ensure: '1.0.0' } } # parameter used in podman::install

      it { is_expected.to contain_package('podman-compose').with_ensure('1.0.0') }
    end
    context 'with machinectl_pkg_ensure set to valid absent' do
      let(:params) { { machinectl_pkg_ensure: 'absent' } } # parameter used in podman::install

      it { is_expected.to contain_package('systemd-container').with_ensure('absent') }
    end

    context 'with nodocker set to valid file' do
      let(:params) { { nodocker: 'file' } } # parameter used in podman::install

      it { is_expected.to contain_file('/etc/containers/nodocker').with_ensure('file') }
    end

    context 'with storage_options set to valid hash' do
      let(:params) { { storage_options: { testing1: { option1: 'value1', option2: 'value2' }, testing2: { option3: 'value3' } } } }

      it do
        is_expected.to contain_ini_setting('/etc/containers/storage.conf [testing1] option1').only_with(
          {
            'section'  => 'testing1',
            'setting'  => 'option1',
            'value'    => 'value1',
            'ensure'   => 'present',
            'path'     => '/etc/containers/storage.conf',
          },
        )
      end

      it do
        is_expected.to contain_ini_setting('/etc/containers/storage.conf [testing1] option2').only_with(
          {
            'section'  => 'testing1',
            'setting'  => 'option2',
            'value'    => 'value2',
            'ensure'   => 'present',
            'path'     => '/etc/containers/storage.conf',
          },
        )
      end

      it do
        is_expected.to contain_ini_setting('/etc/containers/storage.conf [testing2] option3').only_with(
          {
            'section'  => 'testing2',
            'setting'  => 'option3',
            'value'    => 'value3',
            'ensure'   => 'present',
            'path'     => '/etc/containers/storage.conf',
          },
        )
      end
    end

    context 'with containers_options set to valid hash' do
      let(:params) { { containers_options: { testing1: { option1: 'value1', option2: 'value2' }, testing2: { option3: 'value3' } } } }

      it do
        is_expected.to contain_ini_setting('/etc/containers/containers.conf [testing1] option1').only_with(
          {
            'section'  => 'testing1',
            'setting'  => 'option1',
            'value'    => 'value1',
            'ensure'   => 'present',
            'path'     => '/etc/containers/containers.conf',
          },
        )
      end

      it do
        is_expected.to contain_ini_setting('/etc/containers/containers.conf [testing1] option2').only_with(
          {
            'section'  => 'testing1',
            'setting'  => 'option2',
            'value'    => 'value2',
            'ensure'   => 'present',
            'path'     => '/etc/containers/containers.conf',
          },
        )
      end

      it do
        is_expected.to contain_ini_setting('/etc/containers/containers.conf [testing2] option3').only_with(
          {
            'section'  => 'testing2',
            'setting'  => 'option3',
            'value'    => 'value3',
            'ensure'   => 'present',
            'path'     => '/etc/containers/containers.conf',
          },
        )
      end
    end

    context 'with rootless_users set to valid [test, ing]' do
      let(:params) { { rootless_users: ['test', 'ing'] } }
      let(:pre_condition) do
        "# user & file needed by podman::rootless
         user { 'test':
           ensure  => 'present',
           gid     => 1111,
           home    => '/home/test',
           uid     => 3333,
         }
         user { 'ing':
           ensure  => 'present',
           gid     => 1111,
           home    => '/home/ing',
           uid     => 4444,
         }
         file { '/home/test': }
         file { '/home/ing': }
        "
      end

      it { is_expected.to contain_podman__rootless('test').only_with({}) }
      it { is_expected.to contain_podman__rootless('ing').only_with({}) }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_loginctl_user('test') }                       # from podman::rootless
      it { is_expected.to contain_loginctl_user('ing') }                        # from podman::rootless
      it { is_expected.to contain_exec('start_test.slice') }                    # from podman::rootless
      it { is_expected.to contain_exec('start_ing.slice') }                     # from podman::rootless
      it { is_expected.to contain_file('/home/ing/.config/systemd/user') }      # from podman::rootless
      it { is_expected.to contain_file('/home/ing/.config/systemd') }           # from podman::rootless
      it { is_expected.to contain_file('/home/ing/.config') }                   # from podman::rootless
      it { is_expected.to contain_file('/home/test/.config/systemd/user') }     # from podman::rootless
      it { is_expected.to contain_file('/home/test/.config/systemd') }          # from podman::rootless
      it { is_expected.to contain_file('/home/test/.config') }                  # from podman::rootless
      it { is_expected.to contain_file('/etc/containers/systemd/users/4444') }  # from podman::rootless
    end

    context 'with enable_api_socket set to valid true' do
      let(:params) { { enable_api_socket: true } }

      it do # parameter used in podman::service
        is_expected.to contain_service('podman.socket').with(
          {
            'ensure' => 'running',
            'enable' => true,
          },
        )
      end
    end

    context 'with enable_api_socket set to valid true when rootless_users is set to valid [dummy]' do
      let(:params) { { enable_api_socket: true, rootless_users: ['dummy'] } } # parameter used in podman::service & podman::rootless
      let(:pre_condition) do
        "# user & file needed by podman::rootless
         user { 'dummy':
           ensure  => 'present',
           gid     => 1111,
           home    => '/home/dummy',
           uid     => 3333,
         }
         file { '/home/dummy': }
        "
      end

      it do
        is_expected.to contain_service('podman.socket').with(
          {
            'ensure' => 'running',
            'enable' => true,
          },
        )
      end

      it do
        is_expected.to contain_exec('podman rootless api socket dummy').only_with(
          {
            'command'     => 'systemctl --user enable --now podman.socket',
            'path'        => os_facts[:path],
            'user'        => 'dummy',
            'environment' => ['HOME=/home/dummy', 'XDG_RUNTIME_DIR=/run/user/3333', 'DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/3333/bus'],
            'unless'      => 'systemctl --user status podman.socket',
            'require'     => ['Loginctl_user[dummy]', 'Exec[start_dummy.slice]'],
          },
        )
      end

      # only here to reach 100% resource coverage
      it { is_expected.to contain_podman__rootless('dummy') }                # from podman::rootless
      it { is_expected.to contain_loginctl_user('dummy') }                   # from podman::rootless
      it { is_expected.to contain_exec('start_dummy.slice') }                # from podman::rootless
      it { is_expected.to contain_file('/home/dummy/.config/systemd/user') } # from podman::rootless
      it { is_expected.to contain_file('/home/dummy/.config/systemd') }      # from podman::rootless
      it { is_expected.to contain_file('/home/dummy/.config') }              # from podman::rootless
    end

    context 'with manage_subuid set to valid true' do
      let(:params) { { manage_subuid: true } } # parameter used in podman::install

      it { is_expected.to contain_concat('/etc/subuid') }
      it { is_expected.to contain_concat('/etc/subgid') }
      it { is_expected.to contain_concat_fragment('subuid_header') }
      it { is_expected.to contain_concat_fragment('subgid_header') }
    end

    context 'with manage_subuid set to valid true when subid is a valid hash' do
      let(:params) { { manage_subuid: true, subid: { dummy: { subuid: 242, count: 1 } } } } # parameter used in podman::install

      it { is_expected.to contain_concat('/etc/subuid') }
      it { is_expected.to contain_concat('/etc/subgid') }
      it { is_expected.to contain_concat_fragment('subuid_header') }
      it { is_expected.to contain_concat_fragment('subgid_header') }
      it { is_expected.to contain_podman__subuid('dummy') }
      it { is_expected.to contain_podman__subgid('dummy') }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_concat__fragment('subgid_fragment_dummy') } # from podman::subgid
      it { is_expected.to contain_concat__fragment('subuid_fragment_dummy') } # from podman::subuid
    end

    context 'with match_subuid_subgid set to valid false when manage_subuid is true and subid is a valid hash' do
      let(:params) { { match_subuid_subgid: false, manage_subuid: true, subid: { dummy: { subuid: 242, count: 1 } } } } # parameter used in podman::install

      it { is_expected.not_to contain_podman__subuid('dummy') }
      it { is_expected.not_to contain_podman__subgid('dummy') }
    end

    context 'with file_header set to valid #testing when manage_subuid is true' do
      let(:params) { { file_header: '#testing', manage_subuid: true } } # parameter used in podman::install

      it { is_expected.to contain_concat_fragment('subuid_header').with_content('#testing') }
      it { is_expected.to contain_concat_fragment('subgid_header').with_content('#testing') }
    end

    context 'with subid set to valid hash when manage_subuid is true' do
      let(:params) { { subid: { testing: { subuid: 242, count: 1 } }, manage_subuid: true } } # parameter used in podman::install

      it { is_expected.to contain_podman__subuid('testing') }
      it { is_expected.to contain_podman__subgid('testing') }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_concat__fragment('subgid_fragment_testing') } # from podman::subgid
      it { is_expected.to contain_concat__fragment('subuid_fragment_testing') } # from podman::subuid
    end

    context 'with pods set to valid hash' do
      let(:params) { { pods: { test1: { flags: { label: 'dummy1' } }, test2: { flags: { label: 'dummy2' } } } } }

      it { is_expected.to contain_podman__pod('test1').with_flags({ 'label' => 'dummy1' }) }
      it { is_expected.to contain_podman__pod('test2').with_flags({ 'label' => 'dummy2' }) }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_exec('create_pod_test1') } # from podman::pod
      it { is_expected.to contain_exec('create_pod_test2') } # from podman::pod
    end

    context 'with volumes set to valid hash' do
      let(:params) { { volumes: { test1: { flags: { label: 'dummy1' } }, test2: { flags: { label: 'dummy2' } } } } }

      it { is_expected.to contain_podman__volume('test1').with_flags({ 'label' => 'dummy1' }) }
      it { is_expected.to contain_podman__volume('test2').with_flags({ 'label' => 'dummy2' }) }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_exec('podman_create_volume_test1') } # from podman::volume
      it { is_expected.to contain_exec('podman_create_volume_test2') } # from podman::volume
    end

    context 'with images set to valid hash' do
      let(:params) { { images: { test1: { flags: { label: 'dummy1' }, image: 'dummy:242' }, test2: { flags: { label: 'dummy2' }, image: 'dummy:242' } } } }

      it { is_expected.to contain_podman__image('test1').with_flags({ 'label' => 'dummy1' }) }
      it { is_expected.to contain_podman__image('test2').with_flags({ 'label' => 'dummy2' }) }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_exec('pull_image_test1') } # from podman::image
      it { is_expected.to contain_exec('pull_image_test2') } # from podman::image
    end

    context 'with containers set to valid hash' do
      let(:params) { { containers: { test1: { flags: { label: 'dummy1' }, image: 'dummy:242' }, test2: { flags: { label: 'dummy2' }, image: 'dummy:242' } } } }

      it { is_expected.to contain_podman__container('test1').with_flags({ 'label' => 'dummy1' }) }
      it { is_expected.to contain_podman__container('test2').with_flags({ 'label' => 'dummy2' }) }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_exec('podman_create_test1') }           # from podman::container
      it { is_expected.to contain_exec('podman_create_test2') }           # from podman::container
      it { is_expected.to contain_exec('podman_generate_service_test1') } # from podman::container
      it { is_expected.to contain_exec('podman_generate_service_test2') } # from podman::container
      it { is_expected.to contain_exec('podman_remove_container_test1') } # from podman::container
      it { is_expected.to contain_exec('podman_remove_container_test2') } # from podman::container
      it { is_expected.to contain_exec('podman_remove_image_test1') }     # from podman::container
      it { is_expected.to contain_exec('podman_remove_image_test2') }     # from podman::container
      it { is_expected.to contain_exec('verify_container_flags_test1') }  # from podman::container
      it { is_expected.to contain_exec('verify_container_flags_test2') }  # from podman::container
      it { is_expected.to contain_exec('verify_container_image_test1') }  # from podman::container
      it { is_expected.to contain_exec('verify_container_image_test2') }  # from podman::container
      it { is_expected.to contain_service('podman-test1') }               # from podman::container
      it { is_expected.to contain_service('podman-test2') }               # from podman::container
      it { is_expected.to contain_exec('podman_systemd_reload') }         # from podman::container
    end

    context 'with networks set to valid hash' do
      let(:params) { { networks: { test1: { labels: { dummy1: 'dummy1' } }, test2: { labels: { dummy2: 'dummy2' } } } } }

      it { is_expected.to contain_podman__network('test1').with_labels({ 'dummy1' => 'dummy1' }) }
      it { is_expected.to contain_podman__network('test2').with_labels({ 'dummy2' => 'dummy2' }) }

      # only here to reach 100% resource coverage
      it { is_expected.to contain_exec('podman_create_network_test1') } # from podman::network
      it { is_expected.to contain_exec('podman_create_network_test2') } # from podman::network
    end
  end
end
