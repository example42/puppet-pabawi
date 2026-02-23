# @summary Install Pabawi using Docker containers
#
# This class manages the installation of Pabawi using Docker,
# including Docker setup, image management, and container lifecycle.
#
# @param manage_docker
#   Whether to manage the Docker installation. Set to false if Docker is managed elsewhere.
#
# @param image
#   Docker image to use for Pabawi
#
# @param container_name
#   Name for the Docker container
#
# @param environment
#   Environment variables to pass to the container
#
# @param volumes
#   Volume mounts for the container
#
# @param ports
#   Port mappings for the container (host => container)
#
# @param auto_restart
#   Whether to automatically restart the container on failure
#
# @param log_level
#   Application log level (debug, info, warn, error)
#
# @param auth_enabled
#   Whether authentication is enabled
#
# @param jwt_secret
#   JWT secret for authentication (required if auth_enabled is true)
#
# @param database_path
#   Path to application database file
#
# @param concurrent_execution_limit
#   Maximum number of concurrent executions
#
# @example Basic usage
#   include pabawi::install::docker
#
# @example Custom configuration
#   class { 'pabawi::install::docker':
#     image       => 'pabawi/pabawi:v1.2.3',
#     environment => {
#       'NODE_ENV' => 'production',
#       'PORT'     => '3000',
#     },
#     volumes     => ['/data/pabawi:/app/data'],
#   }
#
class pabawi::install::docker (
  Boolean $manage_docker = true,
  String[1] $image = 'example42/pabawi:latest',
  String[1] $container_name = 'pabawi',
  Hash[String[1], String] $environment = {},
  Array[String[1]] $volumes = [],
  Hash[String[1], String[1]] $ports = { '3000' => '3000' },
  Boolean $auto_restart = true,
  Stdlib::Absolutepath $install_dir = '/opt/pabawi',
  String[1] $log_level = 'info',
  Boolean $auth_enabled = false,
  Optional[String[1]] $jwt_secret = undef,
  Stdlib::Absolutepath $database_path = '/var/lib/pabawi/pabawi.db',
  Integer $concurrent_execution_limit = 5,
) {
  # Validate auth configuration
  if $auth_enabled and !$jwt_secret {
    fail('pabawi::install::docker: jwt_secret is required when auth_enabled is true')
  }

  # Create installation directory for .env file
  file { $install_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Create database directory
  $database_dir = dirname($database_path)
  exec { "create_database_dir_${database_path}":
    command => "mkdir -p ${database_dir}",
    path    => ['/usr/bin', '/bin'],
    creates => $database_dir,
  }
  -> file { $database_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Create .env file using concat
  $env_file_path = "${install_dir}/.env"
  concat { 'pabawi_env_file':
    path    => $env_file_path,
    owner   => 'root',
    group   => 'root',
    mode    => '0600',
    require => File[$install_dir],
  }

  # Base configuration fragment
  concat::fragment { 'pabawi_env_base':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Pabawi Base Configuration
      LOG_LEVEL=${log_level}
      AUTH_ENABLED=${auth_enabled}
      JWT_SECRET=${pick($jwt_secret, 'not-set')}
      DATABASE_PATH=${database_path}
      CONCURRENT_EXECUTION_LIMIT=${concurrent_execution_limit}
      | EOT
    order   => '10',
  }

  # Conditionally manage Docker installation
  if $manage_docker {
    class { 'docker':
      ensure => present,
    }
  }

  # Pull the Docker image
  docker::image { $image:
    ensure  => present,
    require => $manage_docker ? {
      true    => Class['docker'],
      default => undef,
    },
  }

  # Create and run the container
  docker::run { $container_name:
    image   => $image,
    env     => $environment.map |$key, $value| { "${key}=${value}" },
    volumes => $volumes + ["${env_file_path}:/app/.env:ro"],
    ports   => $ports.map |$host, $container| { "${host}:${container}" },
    restart => $auto_restart ? {
      true    => 'always',
      default => 'no',
    },
    require => [
      Docker::Image[$image],
      Concat['pabawi_env_file'],
    ],
  }
}
