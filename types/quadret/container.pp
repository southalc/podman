# @summary custom datatype for container entries of podman container quadlet
# @see https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
type Podman::Quadret::Container = Struct[
  Optional['Image'] => String[1],
  Optional['Exec']  => String[1],
]
