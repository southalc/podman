Puppet::Type.newtype(:podman_secret) do
  desc 'Manage podman secrets'

  ensurable do
    desc 'Manage the state of the secret'
    defaultvalues
    defaultto :present
  end

  newparam(:name, namevar: true) do
    desc 'The name of the secret'
    validate do |value|
      raise ArgumentError, 'Secret name cannot be empty' if value.empty?
    end
  end

  newproperty(:secret) do
    desc 'The secret content'
    validate do |value|
      raise ArgumentError, 'Secret content cannot be empty' if value.to_s.empty?
    end

    def sensitive?
      true
    end
  end

  newparam(:path) do
    desc 'Path to file containing secret content'
    validate do |value|
      raise ArgumentError, 'Path must be absolute' unless Puppet::Util.absolute_path?(value)
    end
  end

  newparam(:flags) do
    desc 'Hash of flags to pass to podman secret create'
    defaultto({})

    validate do |value|
      raise ArgumentError, 'Flags must be a hash' unless value.is_a?(Hash)
    end
  end

  newparam(:user) do
    desc 'Optional user for running rootless containers'
  end

  newparam(:show_diff, boolean: true, parent: Puppet::Parameter::Boolean) do
    desc "Whether to display differences when the secret changes, defaulting to
        false. This parameter can be useful for files that may contain configuration
        and no secrets. If the global `show_diff` setting is false, then no diffs
        will be shown even if this parameter is true."

    defaultto :false
  end

  validate do
    if self[:secret] && self[:path]
      raise ArgumentError, 'Only one of secret or path can be specified'
    end

    unless self[:secret] || self[:path]
      raise ArgumentError, 'Either secret or path must be specified'
    end
  end
end
