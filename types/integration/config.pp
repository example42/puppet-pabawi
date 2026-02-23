# Pabawi::Integration::Config type
# Defines the structure for integration configuration
type Pabawi::Integration::Config = Struct[{
  enabled          => Boolean,
  config_path      => Optional[Stdlib::Absolutepath],
  settings         => Hash[String, Data],
}]
