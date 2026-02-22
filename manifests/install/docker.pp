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
) {
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
    volumes => $volumes,
    ports   => $ports.map |$host, $container| { "${host}:${container}" },
    restart => $auto_restart ? {
      true    => 'always',
      default => 'no',
    },
    require => Docker::Image[$image],
  }
}
