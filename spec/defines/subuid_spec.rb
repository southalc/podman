require 'spec_helper'

describe 'podman::subuid' do
  let(:title) { 'testing-title' }

  on_supported_os.each do |os, os_facts|
    context "on #{os} when all mandatory parameters are set to valid values" do
      let(:facts) { os_facts }
      let(:params) { { subuid: 2_000_000, count: 1000 } }

      it { is_expected.to compile }

      it do
        is_expected.to contain_concat__fragment('subuid_fragment_testing-title').only_with(
          {
            'order'   => '10',
            'target'  => '/etc/subuid',
            'content' => 'testing-title:2000000:1000'
          },
        )
      end
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

    context 'with subuid set to valid 242 and count set to valid 3' do
      let(:params) { { subuid: 242, count: 3 } }

      it { is_expected.to contain_concat__fragment('subuid_fragment_testing-title').with_content('testing-title:242:3') }
    end

    context 'with order set to valid 242 when all mandatory parameters are set to valid values' do
      let(:params) { { order: 242, subuid: 2_000_000, count: 1000 } }

      it { is_expected.to contain_concat__fragment('subuid_fragment_testing-title').with_order(242) }
    end
  end
end
