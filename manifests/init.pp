# @summary Main class for Pabawi module
#
# This class serves as the entry point for the Pabawi module, orchestrating
# all subcomponents based on Hiera configuration. It manages proxy setup,
# application installation, and various integrations.
#
# @param proxy_manage
#   Whether to manage proxy configuration. When true, the class specified
#   in proxy_class will be included.
#
# @param proxy_class
#   The class to use for proxy configuration. Must be a valid Puppet class name.
#   Default: 'pabawi::proxy::nginx'
#
# @param install_manage
#   Whether to manage application installation. When true, the class specified
#   in install_class will be included.
#
# @param install_class
#   The class to use for application installation. Must be a valid Puppet class name.
#   Default: 'pabawi::install::npm'
#
# @param integrations
#   Array of integration names to enable. Integration-specific configuration
#   is managed via class parameters in Hiera.
#   Example: ['bolt', 'puppetdb', 'hiera']
#
# @example Basic usage with defaults
#   include pabawi
#
# @example Custom installation method
#   class { 'pabawi':
#     install_class => 'pabawi::install::docker',
#   }
#
# @example Disable proxy management
#   class { 'pabawi':
#     proxy_manage => false,
#   }
#
# @example Enable integrations
#   class { 'pabawi':
#     integrations => ['bolt', 'puppetdb'],
#   }
#
class pabawi (
  Boolean $proxy_manage = true,
  String[1] $proxy_class = 'pabawi::proxy::nginx',
  Boolean $install_manage = true,
  String[1] $install_class = 'pabawi::install::npm',
  Array[String[1]] $integrations = [],
) {
  # Validate proxy_class is a valid class name format
  if $proxy_manage {
    unless $proxy_class =~ /^[a-z][a-z0-9_]*(::[a-z][a-z0-9_]*)*$/ {
      fail("Invalid proxy_class '${proxy_class}': must be a valid Puppet class name")
    }
  }

  # Validate install_class is a valid class name format
  if $install_manage {
    unless $install_class =~ /^[a-z][a-z0-9_]*(::[a-z][a-z0-9_]*)*$/ {
      fail("Invalid install_class '${install_class}': must be a valid Puppet class name")
    }
  }

  # No validation needed for integrations array - just a list of names

  # Conditionally include proxy class
  if $proxy_manage {
    include $proxy_class
  }

  # Conditionally include installation class
  # Ensure installation happens after proxy configuration if both are managed
  if $install_manage {
    if $proxy_manage {
      Class[$proxy_class] -> Class[$install_class]
    }
    include $install_class
  }

  # Process integrations - simply include each class
  $integrations.each |String $name| {
    $integration_class = "pabawi::integrations::${name}"

    notify { "pabawi_integration_${name}":
      message  => "Enabling integration: ${integration_class}",
      loglevel => 'notice',
    }

    include $integration_class
  }
}
