# frozen_string_literal: true

require 'spec_helper'

describe 'Podman::Unit::Volume' do
  it { is_expected.to allow_value({ 'Driver' => 'image' }) }
end
