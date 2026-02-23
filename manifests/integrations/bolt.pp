# @summary Configure Pabawi integration with Puppet Bolt
#
# This class manages the integration between Pabawi and Puppet Bolt,
# writing configuration to the .env file and optionally managing the Bolt package
# and project repository.
#
# @param enabled
#   Whether the integration is enabled (sets BOLT_ENABLED in .env)
#
# @param manage_package
#   Whether to install the bolt package
#
# @param project_path
#   Local path for bolt project directory
#
# @param project_path_source
#   Git URL to clone bolt project from (optional)
#
# @param command_whitelist
#   Array of allowed commands for bolt execution
#
# @param command_whitelist_allow_all
#   Whether to allow all commands (bypasses whitelist)
#
# @param execution_timeout
#   Timeout for bolt command execution in milliseconds
#
# @example Basic usage via main class
#   class { 'pabawi':
#     integrations => ['bolt'],
#   }
#
#   # Configure via Hiera
#   pabawi::integrations::bolt::project_path: '/opt/bolt-project'
#
# @example With git repository
#   class { 'pabawi':
#     integrations => ['bolt'],
#   }
#
#   # Configure via Hiera
#   pabawi::integrations::bolt::project_path: '/opt/bolt-project'
#   pabawi::integrations::bolt::project_path_source: 'https://github.com/example/bolt-project.git'
#   pabawi::integrations::bolt::command_whitelist:
#     - 'plan run'
#     - 'task run'
#
class pabawi::integrations::bolt (
  Boolean $enabled = true,
  Boolean $manage_package = false,
  Stdlib::Absolutepath $project_path = '/opt/pabawi/control-repo',
  Optional[String[1]] $project_path_source = undef,
  Array[String[1]] $command_whitelist = [],
  Boolean $command_whitelist_allow_all = false,
  Integer $execution_timeout = 300000,
) {
  # Validate required parameters
  unless $project_path {
    fail('pabawi::integrations::bolt requires project_path parameter')
  }

  # Manage bolt package if requested
  if $manage_package {
    package { 'puppet-bolt':
      ensure => installed,
    }
  }

  # Clone git repository if source is provided
  if $project_path_source {
    # Ensure parent directory exists
    $parent_dir = dirname($project_path)
    exec { "create_bolt_parent_dir_${project_path}":
      command => "mkdir -p ${parent_dir}",
      path    => ['/usr/bin', '/bin'],
      creates => $parent_dir,
    }

    vcsrepo { $project_path:
      ensure   => present,
      provider => git,
      source   => $project_path_source,
      require  => Exec["create_bolt_parent_dir_${project_path}"],
    }
  }

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_bolt':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Bolt Integration
      BOLT_ENABLED=${enabled}
      BOLT_PROJECT_PATH=${project_path}
      BOLT_COMMAND_WHITELIST=${stdlib::to_json($command_whitelist)}
      BOLT_COMMAND_WHITELIST_ALLOW_ALL=${command_whitelist_allow_all}
      BOLT_EXECUTION_TIMEOUT=${execution_timeout}
      | EOT
    order   => '20',
  }
}
