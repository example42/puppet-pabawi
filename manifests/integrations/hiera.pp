# @summary Configure Pabawi integration with Hiera
#
# This class manages the integration between Pabawi and Hiera,
# including control repository management and .env configuration.
#
# @param enabled
#   Whether the integration is enabled (sets HIERA_ENABLED in .env)
#
# @param settings
#   Hash of Pabawi application configuration settings written to .env with HIERA_ prefix.
#   Supported keys: control_repo_path, config_path, environments, fact_source_prefer_puppetdb, fact_source_local_path
#
# @param manage_package
#   Whether to install hiera package (if separate package needed)
#
# @param control_repo_source
#   Git URL to clone control repository from (optional). Clones to settings['control_repo_path']
#
# @example Basic usage with settings hash
#   class { 'pabawi::integrations::hiera':
#     settings => {
#       'control_repo_path'              => '/opt/pabawi/control-repo',
#       'config_path'                    => 'hiera_pabawi.yaml',
#       'environments'                   => ['production', 'development'],
#       'fact_source_prefer_puppetdb'    => true,
#       'fact_source_local_path'         => '/opt/pabawi/facts',
#     },
#   }
#
# @example With git repository
#   class { 'pabawi::integrations::hiera':
#     settings => {
#       'control_repo_path' => '/opt/pabawi/control-repo',
#       'config_path'       => 'hiera_pabawi.yaml',
#       'environments'      => ['production'],
#     },
#     control_repo_source => 'https://github.com/example/control-repo.git',
#   }
#
class pabawi::integrations::hiera (
  Boolean $enabled = true,
  Hash $settings = {},
  Boolean $manage_package = false,
  Optional[String[1]] $control_repo_source = undef,
) {
  # Validate required parameters when integration is enabled
  if $enabled {
    if $control_repo_source and !$settings['control_repo_path'] {
      fail('pabawi::integrations::hiera: settings[\'control_repo_path\'] is required when control_repo_source is provided')
    }
  }

  # Manage hiera package if requested
  if $manage_package {
    package { 'hiera':
      ensure => installed,
    }
  }

  # Clone git repository if source is provided
  if $control_repo_source {
    $control_repo_path = $settings['control_repo_path']
    # Ensure parent directory exists
    $parent_dir = dirname($control_repo_path)
    exec { "create_hiera_parent_dir_${control_repo_path}":
      command => "mkdir -p ${parent_dir}",
      path    => ['/usr/bin', '/bin'],
      creates => $parent_dir,
    }

    vcsrepo { $control_repo_path:
      ensure   => present,
      provider => git,
      source   => $control_repo_source,
      require  => Exec["create_hiera_parent_dir_${control_repo_path}"],
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
    $memo + { "HIERA_${env_key}" => $transformed }
  }

  # Build environment variable lines
  $env_lines = $env_vars.map |$key, $value| {
    "${key}=${value}"
  }.join("\n")

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_hiera':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Hiera Integration
      HIERA_ENABLED=${enabled ? { true => 'true', false => 'false' }}
      ${env_lines}
      | EOT
    order   => '23',
  }
}
