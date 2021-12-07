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
  let(:pre_condition) { 'include podman' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
