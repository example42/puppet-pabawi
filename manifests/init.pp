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
#   Hash of integrations to configure. Keys are integration names,
#   values are hashes containing 'enabled' boolean plus integration-specific configuration.
#   Example: {
#     'bolt' => {
#       'enabled' => true,
#       'project_path' => '/opt/bolt-project',
#       'command_whitelist' => ['ls', 'pwd'],
#     },
#     'puppetdb' => {
#       'enabled' => true,
#       'server_url' => 'https://puppetdb.example.com:8081',
#     },
#   }
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
#     integrations => {
#       'bolt' => {
#         'enabled' => true,
#         'project_path' => '/opt/bolt-project',
#       },
#       'puppetdb' => {
#         'enabled' => true,
#         'server_url' => 'https://puppetdb.example.com:8081',
#       },
#     },
#   }
#
class pabawi (
  Boolean $proxy_manage = true,
  String[1] $proxy_class = 'pabawi::proxy::nginx',
  Boolean $install_manage = true,
  String[1] $install_class = 'pabawi::install::npm',
  Hash[String[1], Hash] $integrations = {},
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

  # Validate integrations hash structure
  $integrations.each |String $name, Hash $config| {
    unless $config['enabled'] =~ Boolean {
      fail("Integration '${name}' must have an 'enabled' boolean key")
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

  # Process integrations from hash
  $integrations.each |String $name, Hash $config| {
    if $config['enabled'] {
      $integration_class = "pabawi::integrations::${name}"

      # Log that we're attempting to enable this integration
      notify { "pabawi_integration_${name}":
        message  => "Enabling integration: ${integration_class}",
        loglevel => 'notice',
      }

      # Include the integration class with its configuration
      # Remove the 'enabled' key and pass remaining config as parameters
      $integration_params = $config.filter |$key, $value| { $key != 'enabled' }
      class { $integration_class:
        * => $integration_params,
      }
    }
  }
}
