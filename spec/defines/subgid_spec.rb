require 'spec_helper'

describe 'podman::subgid' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      subgid: 2_000_000,
      count: 1000,
    }
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
