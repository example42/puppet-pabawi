# @summary Configure Pabawi integration with Puppet Bolt
#
# This class manages the integration between Pabawi and Puppet Bolt,
# including configuration file creation and validation.
#
# @param project_path
#   Path to the Bolt project directory
#
# @param bolt_config_path
#   Optional path to Bolt configuration file
#
# @param bolt_settings
#   Additional Bolt integration settings
#
# @example Basic usage
#   class { 'pabawi::integrations::bolt':
#     project_path => '/opt/bolt-project',
#   }
#
# @example With custom settings
#   class { 'pabawi::integrations::bolt':
#     project_path => '/opt/bolt-project',
#     bolt_settings => {
#       'timeout' => 300,
#       'concurrency' => 10,
#     },
#   }
#
class pabawi::integrations::bolt (
  Optional[Stdlib::Absolutepath] $project_path = undef,
  Optional[Stdlib::Absolutepath] $bolt_config_path = undef,
  Hash $bolt_settings = {},
) {
  # Validate that project_path is provided
  unless $project_path {
    fail('pabawi::integrations::bolt requires project_path parameter')
  }

  # Validate that Bolt project path exists
  unless $facts['os']['family'] == 'windows' {
    exec { 'validate_bolt_project_path':
      command => "test -d ${project_path}",
      path    => ['/usr/bin', '/bin'],
      unless  => "test -d ${project_path}",
      onlyif  => 'true',
    }
  }

  # Create Pabawi integration configuration directory
  ensure_resource('file', '/etc/pabawi', {
    'ensure' => 'directory',
    'mode'   => '0755',
    'owner'  => 'root',
    'group'  => 'root',
  })

  # Create Bolt integration configuration
  $config_content = {
    'bolt' => {
      'enabled'      => true,
      'project_path' => $project_path,
      'config_path'  => $bolt_config_path,
      'settings'     => $bolt_settings,
    },
  }

  file { '/etc/pabawi/bolt-integration.yaml':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => to_yaml($config_content),
    require => File['/etc/pabawi'],
  }

  # Log integration status
  notify { 'pabawi_bolt_integration_enabled':
    message  => "Pabawi Bolt integration enabled for project: ${project_path}",
    loglevel => 'notice',
  }
}
