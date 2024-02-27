# frozen_string_literal: true

require 'spec_helper'

describe 'Podman::Unit::Container' do
  it { is_expected.to allow_value({ 'Image' => 'busybox' }) }
  it { is_expected.to allow_value({ 'PublishPort' => [1234] }) }
  it { is_expected.to allow_value({ 'PublishPort' => ['1234-12346'] }) }
  it { is_expected.to allow_value({ 'PublishPort' => [1234, '123.111.1.1:55:72'] }) }
  it { is_expected.to allow_value({ 'Exec'  => '/bin/bash' }) }
  it { is_expected.to allow_value({ 'Exec'  => './entrypoint.sh' }) }
end
