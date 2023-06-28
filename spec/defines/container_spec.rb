require 'spec_helper'

describe 'podman::container' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      image: 'registry:latest',
    }
  end
  let(:pre_condition) { 'include podman' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      context "with flag['label'] set" do
        let(:params) do
          super().merge(flags: { label: 'a=b' })
        end

        it { is_expected.to compile.with_all_deps }
      end
    end
  end
end
