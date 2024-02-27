require 'spec_helper'

describe 'Podman::Quadret::Container' do
  it { is_expected.to allow_value({ 'Image' => 'busybox' }) }
  it { is_expected.to allow_value({ 'Exec'  => '/bin/bash' }) }
  it { is_expected.to allow_value({ 'Exec'  => './entrypoint.sh' }) }
end
