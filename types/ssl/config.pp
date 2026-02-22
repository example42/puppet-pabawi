# Pabawi::SSL::Config type
# Defines the structure for SSL configuration
type Pabawi::SSL::Config = Struct[{
  enable           => Boolean,
  self_signed      => Boolean,
  cert_source      => Optional[String[1]],
  key_source       => Optional[String[1]],
  cert_path        => Stdlib::Absolutepath,
  key_path         => Stdlib::Absolutepath,
}]
