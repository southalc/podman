# @summary custom datatype for Volume entries of podman container quadlet
# @see https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html
type Podman::Unit::Volume = Struct[
  Optional['ContainersConfModule'] => Variant[Stdlib::Unixpath,Array[Stdlib::Unixpath,1]],
  Optional['Copy']                 => Boolean,
  Optional['Device']               => String[1],
  Optional['Driver']               => String[1],
  Optional['GlobalArgs']           => Variant[String[1],Array[String[1],1]],
  Optional['Group']                => String[1],
  Optional['Image']                => String[1],
  Optional['Label']                => Variant[String[1],Array[String[1],1]],
  Optional['Options']              => String[1],
  Optional['PodmanArgs']           => Variant[String[1],Array[String[1]]],
  Optional['Type']                 => String[1],
  Optional['User']                 => String[1],
  Optional['VolumeName']           => String[1],
]
