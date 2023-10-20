# frozen_string_literal: true

require 'json'
require 'etc'

Facter.add(:podman_version) do
  confine { Facter::Core::Execution.which('podman') }

  setcode do
    begin
      JSON.parse(Facter::Core::Execution.exec("podman version --format '{{json .}}'"))
    rescue
      nil
    end
  end
end

Facter.add(:podman, type: :aggregate) do
  confine kernel: :linux
  confine { Facter.value(:podman_version) }

  chunk(:version) do
    { 'version' => Facter.value(:podman_version).dig('Client', 'Version') }
  end

  chunk(:socket_root) do
    path = '/run/podman/podman.sock'
    if File.exist?(path)
      { 'socket' => { 'root' => path } }
    else
      nil
    end
  end

  chunk(:socket_user) do
    begin
      val = {}
      Dir.glob('/run/user/*/podman/podman.sock') do |path|
        next unless File.exist?(path)
        uid = path.split(File::SEPARATOR)[3].to_i

        next if uid == 0

        val['socket'] = {} if val['socket'].nil?
        val['socket'][Etc.getpwuid(uid)[:name]] = path
      end

      val
    rescue
      nil
    end
  end
end
