# frozen_string_literal: true

require 'spec_helper'

describe 'podman::rootless' do
  let(:title) { 'user1' }
  let(:params) do
    {}
  end
  let(:pre_condition) do
    <<~END
      include podman
      group { 'user1': }
      -> user { 'user1':
        gid        => 'user1',
        home       => '/home/user1',
      }
      -> file { '/home/user1':
        ensure => directory,
        owner  => 'user1',
        group  => 'user1',
        mode   => '0700',
      }
    END
  end

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
