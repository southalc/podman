#!/opt/puppetlabs/puppet/bin/ruby
require 'json'

unless File.file?('/usr/bin/podman')
  exit
end

unless File.file?('/usr/bin/skopeo')
  exit
end

containers = {}

# podman command output captured as a multi-line string
output = `/usr/bin/podman container list --all --no-trunc --format '{{.Names}} {{.Image}}'`

# Split output on newline character, get values and push to containers{}
output.split(%r{\r?\n|\r}).each do |container|
  parts = container.split(' ')
  name = parts[0].chomp
  image_name = parts[1].chomp
  digest = `podman image inspect #{image_name} --format '{{.Digest}}'`
  latest_registry_image = JSON.parse(`/usr/bin/skopeo inspect docker://#{image_name}`)
  puppet_resource_flags = `podman container inspect #{name} --format '{{.Config.Labels.puppet_resource_flags}}'`.chomp
  containers[name] = {
    'image_name'            => image_name,
    'puppet_resource_flags' => puppet_resource_flags,
    'running_digest'        => digest.chomp,
    'latest_digest'         => latest_registry_image['Digest'],
  }
end

podman_containers = { 'podman_containers' => containers }
puts podman_containers.to_json
