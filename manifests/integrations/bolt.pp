# @summary Configure Pabawi integration with Puppet Bolt
#
# This class manages the integration between Pabawi and Puppet Bolt,
# writing configuration to the .env file and optionally managing the Bolt package
# and project repository.
#
# @param enabled
#   Whether the integration is enabled (sets BOLT_ENABLED in .env)
#
# @param settings
#   Hash of Pabawi application configuration settings written to .env with BOLT_ prefix.
#   Supported keys: project_path, execution_timeout
#
# @param manage_package
#   Whether to install the bolt package
#
# @param project_path_source
#   Git URL to clone bolt project from (optional). Clones to settings['project_path']
#
# @example Basic usage with settings hash
#   class { 'pabawi::integrations::bolt':
#     settings => {
#       'project_path'      => '/opt/pabawi/bolt-project',
#       'execution_timeout' => 300000,
#     },
#   }
#
# @example With git repository
#   class { 'pabawi::integrations::bolt':
#     settings => {
#       'project_path' => '/opt/pabawi/bolt-project',
#     },
#     project_path_source => 'https://github.com/example/bolt-project.git',
#   }
#
class pabawi::integrations::bolt (
  Boolean $enabled = true,
  Hash $settings = {},
  Boolean $manage_package = false,
  Optional[String[1]] $project_path_source = undef,
) {
  # Validate required parameters when integration is enabled
  if $enabled {
    if $project_path_source and !$settings['project_path'] {
      fail('pabawi::integrations::bolt: settings[\'project_path\'] is required when project_path_source is provided')
    }
  }

  # Manage bolt package if requested
  if $manage_package {
    package { 'puppet-bolt':
      ensure => installed,
    }
  }

  # Clone git repository if source is provided
  if $project_path_source {
    $project_path = $settings['project_path']
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

  # Transform settings hash values to .env format
  # Arrays -> JSON, Booleans -> lowercase strings, Integers -> strings, undef/empty -> 'not-set'
  $env_vars = $settings.reduce({}) |$memo, $pair| {
    $key = $pair[0]
    $value = $pair[1]

    # Transform value based on type
    $transformed = $value ? {
      Array   => inline_template('[<%= @value.map { |v| "\"#{v}\"" }.join(",") %>]'),
      Boolean => $value ? { true => 'true', false => 'false' },
      Integer => String($value),
      String  => $value,
      Undef   => 'not-set',
      default => pick($value, 'not-set'),
    }

    $env_key = upcase($key)
    $memo + { "BOLT_${env_key}" => $transformed }
  }

  # Build environment variable lines
  $env_lines = $env_vars.map |$key, $value| {
    "${key}=${value}"
  }.join("\n")

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_bolt':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Bolt Integration
      BOLT_ENABLED=${enabled ? { true => 'true', false => 'false' }}
      ${env_lines}
      | EOT
    order   => '20',
  }
}
