# @summary custom datatype that validates different filenames for quadlet units
# @see https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
type Podman::Quadlet_name = Pattern[/^[a-zA-Z0-9:\-_.\\@%]+\.(container|volume|pod|network)$/]
