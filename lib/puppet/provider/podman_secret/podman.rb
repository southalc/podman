require 'tempfile'
require 'base64'

Puppet::Type.type(:podman_secret).provide(:podman) do
  desc 'Podman secret provider'

  commands podman: 'podman'

  def exists?
    secret_exists?
    !secret_value_changed?
  end

  def secret_exists?
    execute_podman_command('secret', 'inspect', resource[:name])
  rescue Puppet::ExecutionFailure
    false
  end

  def secret_value_changed?
    if resource[:secret]
      secret != resource[:secret]
    elsif resource[:path]
      new_secret = File.read(resource[:path]) if File.exist?(resource[:path])
      secret != new_secret
    end
  end

  def secret
    output = execute_podman_command(
      'secret',
      'inspect',
      resource[:name],
      '--showsecret',
      '--format',
      '{{.SecretData}}',
    )

    output.chomp
  rescue StandardError => e
    Puppet.debug("Failed to retrieve secret content: #{e.message}")
    nil
  end

  def create
    destroy

    args = ['secret', 'create']

    # Process flags
    flags = resource[:flags] || {}
    flags.each do |key, value|
      if value.is_a?(Array)
        value.each do |v|
          args << "--#{key}"
          args << v.to_s
        end
      elsif value.nil? || value == true
        args << "--#{key}"
      else
        args << "--#{key}"
        args << value.to_s
      end
    end

    args << resource[:name]

    if resource[:path]
      # Use file path directly
      args << resource[:path]
      execute_podman_command(args)
    else
      # Handle secret content from parameter - this avoids trailing newlines
      create_secret_from_content(args, resource[:secret])
    end
  end

  def destroy
    return unless secret_exists?
    execute_podman_command('secret', 'rm', resource[:name])
  end

  private

  def create_secret_from_content(args, secret_content)
    # Create a temporary file with the exact secret content (no trailing newline)
    Tempfile.create('podman_secret') do |tempfile|
      # Write content without adding newline
      tempfile.write(secret_content.to_s)
      tempfile.flush

      # Add the tempfile path to args and execute
      final_args = args + [tempfile.path]
      execute_podman_command(final_args)
    end
  end

  def execute_podman_command(*args)
    if resource[:user]
      # Set up environment for rootless user
      user_info = Etc.getpwnam(resource[:user])
      env = {
        'HOME' => user_info.dir,
        'XDG_RUNTIME_DIR' => "/run/user/#{user_info.uid}",
      }

      Puppet::Util::Execution.execute(
        [command(:podman)] + args,
        uid: user_info.uid,
        gid: user_info.gid,
        custom_environment: env,
        cwd: user_info.dir,
        failonfail: true,
        combine: false,
      )
    else
      # This intentionally avoids commands: podman usage in order to define
      # the command ourselves and pass combine => false. This prevents stdout
      # and stderr from being combined and breaking the output from podman.
      # For example, secrets are printed as JSON, but if stderr is present,
      # such as a warning, the JSON will not be parseable.
      podman = Puppet::Provider::Command.new(
        'podman',
        command(:podman),
        Puppet::Util,
        Puppet::Util::Execution,
        {
          failonfail: true,
          combine: false,
        },
      )

      podman.execute(args)
    end
  end
end
