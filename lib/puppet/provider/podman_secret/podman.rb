require 'tempfile'
require 'base64'

Puppet::Type.type(:podman_secret).provide(:podman) do
  desc 'Podman secret provider'

  commands podman: 'podman'

  def exists?
    podman('secret', 'inspect', resource[:name])
    true
  rescue Puppet::ExecutionFailure
    false
  end

  def create
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
    podman('secret', 'rm', resource[:name])
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

  def execute_podman_command(args)
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
      )
    else
      podman(*args)
    end
  end
end
