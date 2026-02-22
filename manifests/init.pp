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
# @param bolt_enable
#   Whether to enable Puppet Bolt integration.
#
# @param puppetdb_enable
#   Whether to enable PuppetDB integration.
#
# @param integrations
#   Hash of additional integrations to enable. Keys are integration names,
#   values are boolean flags indicating whether the integration is enabled.
#   Example: { 'terraform' => true, 'ansible' => false }
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
#     bolt_enable      => true,
#     puppetdb_enable  => true,
#     integrations     => {
#       'terraform' => true,
#       'ansible'   => true,
#     },
#   }
#
class pabawi (
  Boolean $proxy_manage = true,
  String[1] $proxy_class = 'pabawi::proxy::nginx',
  Boolean $install_manage = true,
  String[1] $install_class = 'pabawi::install::npm',
  Boolean $bolt_enable = false,
  Boolean $puppetdb_enable = false,
  Hash[String[1], Boolean] $integrations = {},
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

  # Validate integrations hash contains only boolean values
  $integrations.each |String $name, $enabled| {
    unless $enabled =~ Boolean {
      fail("Integration '${name}' must have a boolean value, got: ${enabled}")
    }
  }

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

  # Process built-in integrations
  if $bolt_enable {
    include pabawi::integrations::bolt
  }

  if $puppetdb_enable {
    include pabawi::integrations::puppetdb
  }

  # Process custom integrations from hash
  $integrations.each |String $name, Boolean $enabled| {
    if $enabled {
      $integration_class = "pabawi::integrations::${name}"

      # Log that we're attempting to enable this integration
      # If the class doesn't exist, Puppet will fail with a descriptive error
      # This is intentional - missing integration classes should be caught early
      notify { "pabawi_integration_${name}":
        message  => "Enabling integration: ${integration_class}",
        loglevel => 'notice',
      }

      # Include the integration class
      # Puppet will fail compilation if the class doesn't exist
      include $integration_class
    }
  }
}
