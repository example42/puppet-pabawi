# @summary Configure Pabawi integration with Hiera
#
# This class manages the integration between Pabawi and Hiera,
# including control repository management and .env configuration.
#
# @param enabled
#   Whether the integration is enabled (sets HIERA_ENABLED in .env)
#
# @param manage_package
#   Whether to install hiera package (if separate package needed)
#
# @param control_repo_path
#   Local path for control repository
#
# @param control_repo_source
#   Git URL to clone control repository from (optional)
#
# @param config_path
#   Path to hiera configuration file (relative to control repo)
#
# @param environments
#   Array of Puppet environments to support
#
# @param fact_source_prefer_puppetdb
#   Whether to prefer PuppetDB as fact source over local files
#
# @param fact_source_local_path
#   Local path for fact files (if not using PuppetDB)
#
# @example Basic usage
#   class { 'pabawi':
#     integrations => ['hiera'],
#   }
#
#   # Configure via Hiera
#   pabawi::integrations::hiera::control_repo_path: '/opt/control-repo'
#
# @example With git repository
#   class { 'pabawi':
#     integrations => ['hiera'],
#   }
#
#   # Configure via Hiera
#   pabawi::integrations::hiera::control_repo_path: '/opt/control-repo'
#   pabawi::integrations::hiera::control_repo_source: 'https://github.com/example/control-repo.git'
#   pabawi::integrations::hiera::environments:
#     - 'production'
#     - 'development'
#
class pabawi::integrations::hiera (
  Boolean $enabled = true,
  Boolean $manage_package = false,
  Optional[String] $control_repo_path = undef,
  Optional[String[1]] $control_repo_source = undef,
  String[1] $config_path = 'hiera_pabawi.yaml',
  Array[String[1]] $environments = ['production'],
  Boolean $fact_source_prefer_puppetdb = true,
  Optional[String] $fact_source_local_path = undef,
) {
  # Validate required parameters
  unless $control_repo_path {
    fail('pabawi::integrations::hiera requires control_repo_path parameter')
  }

  # Manage hiera package if requested
  if $manage_package {
    package { 'hiera':
      ensure => installed,
    }
  }

  # Clone git repository if source is provided
  if $control_repo_source {
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

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_hiera':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Hiera Integration
      HIERA_ENABLED=${enabled}
      HIERA_CONTROL_REPO_PATH=${control_repo_path}
      HIERA_CONFIG_PATH=${config_path}
      HIERA_ENVIRONMENTS=${to_json($environments)}
      HIERA_FACT_SOURCE_PREFER_PUPPETDB=${fact_source_prefer_puppetdb}
      HIERA_FACT_SOURCE_LOCAL_PATH=${fact_source_local_path}
      | EOT
    order   => '23',
  }
}
