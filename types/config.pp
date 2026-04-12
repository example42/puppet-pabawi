# Pabawi::Config type
# Defines the structure for main module configuration
type Pabawi::Config = Struct[{
  proxy_manage   => Boolean,
  proxy_class    => String[1],
  install_manage => Boolean,
  install_class  => String[1],
  integrations   => Array[String[1]],
}]
