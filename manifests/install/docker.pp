# @summary Install Pabawi as a Docker container managed by systemd
#
# This class runs the Pabawi Docker container as a native systemd service
# using `docker run` directly, without requiring the puppetlabs/docker module.
# Docker packages can optionally be installed by this class.
#
# @param manage_docker
#   Whether to install Docker packages. Default: false (assumes Docker is
#   already installed and managed elsewhere).
#
# @param docker_package
#   Name of the Docker package to install when manage_docker is true.
#
# @param image
#   Docker image to use for Pabawi.
#
# @param container_name
#   Name for the Docker container.
#
# @param environment
#   Environment variables to pass to the container.
#
# @param volumes
#   Volume mounts for the container (Docker -v format strings).
#
# @param ports
#   Port mappings for the container (host => container).
#
# @param bind_address
#   IP address to bind port mappings to. Defaults to 127.0.0.1 when
#   pabawi::proxy_manage is true (looked up from Hiera), 0.0.0.0 otherwise.
#
# @param auto_restart
#   Whether systemd should restart the container on failure.
#
# @param install_dir
#   Directory for configuration files (.env).
#
# @param log_level
#   Application log level (debug, info, warn, error).
#
# @param auth_enabled
#   Whether authentication is enabled.
#
# @param jwt_secret
#   JWT secret for authentication. If not provided, a random secret is
#   generated automatically.
#
# @param database_path
#   Path to application database file inside the container.
#   Must match a writable path in the container image (default: /opt/pabawi/data/pabawi.db).
#
# @param concurrent_execution_limit
#   Maximum number of concurrent executions.
#
# @param command_whitelist
#   Array of allowed commands for execution control.
#
# @param command_whitelist_allow_all
#   Whether to bypass command whitelist and allow all commands.
#
# @param database_host_dir
#   Host directory to mount for the database. Will be mapped to the
#   container directory containing database_path.
#
# @param container_uid
#   UID of the application user inside the container. Used to set
#   ownership on the host database directory.
#
# @param container_gid
#   GID of the application group inside the container.
#
# @param docker_extra_args
#   Additional arguments to pass to `docker run`.
#
# @example Basic usage (Docker already installed)
#   include pabawi::install::docker
#
# @example Install Docker packages and use custom image
#   class { 'pabawi::install::docker':
#     manage_docker => true,
#     image         => 'example42/pabawi:v1.2.3',
#   }
#
# @example Custom configuration
#   class { 'pabawi::install::docker':
#     image       => 'example42/pabawi:v1.2.3',
#     environment => {
#       'NODE_ENV' => 'production',
#       'PORT'     => '3000',
#     },
#     volumes     => ['/data/pabawi:/app/data'],
#   }
#
class pabawi::install::docker (
  Boolean $manage_docker = false,
  String[1] $docker_package = 'docker-ce',
  String[1] $image = 'example42/pabawi:latest',
  String[1] $container_name = 'pabawi',
  Hash[String[1], String] $environment = {},
  Array[String[1]] $volumes = [],
  Hash[String[1], String[1]] $ports = { '3000' => '3000' },
  String[1] $bind_address = lookup('pabawi::proxy_manage', Boolean, 'first', false) ? {
    true    => '127.0.0.1',
    default => '0.0.0.0',
  },
  Boolean $auto_restart = true,
  Stdlib::Absolutepath $install_dir = '/opt/pabawi',
  String[1] $log_level = 'info',
  Boolean $auth_enabled = false,
  String[1] $jwt_secret = fqdn_rand_string(64),
  Stdlib::Absolutepath $database_path = '/opt/pabawi/data/pabawi.db',
  Stdlib::Absolutepath $database_host_dir = '/opt/pabawi/data',
  Integer $container_uid = 1001,
  Integer $container_gid = 1001,
  Integer $concurrent_execution_limit = 5,
  Array[String[1]] $command_whitelist = [],
  Boolean $command_whitelist_allow_all = false,
  String $docker_extra_args = '',
) {
  # Docker binary path
  $docker_bin = '/usr/bin/docker'

  # Optionally install Docker packages
  if $manage_docker {
    package { $docker_package:
      ensure => installed,
    }

    service { 'docker':
      ensure  => running,
      enable  => true,
      require => Package[$docker_package],
    }
  }

  # Create installation directory for .env file
  file { $install_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  # Create database host directory with container user ownership
  exec { "create_database_dir_${database_host_dir}":
    command => "mkdir -p ${database_host_dir}",
    path    => ['/usr/bin', '/bin'],
    creates => $database_host_dir,
  }
  -> file { $database_host_dir:
    ensure => directory,
    owner  => $container_uid,
    group  => $container_gid,
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
  $command_whitelist_json = $command_whitelist.empty ? {
    true    => '[]',
    default => "[\"${command_whitelist.join('","')}\"]",
  }
  concat::fragment { 'pabawi_env_base':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Pabawi Base Configuration
      HOST=${bind_address}
      LOG_LEVEL=${log_level}
      AUTH_ENABLED=${auth_enabled}
      JWT_SECRET=${jwt_secret}
      DATABASE_PATH=${database_path}
      CONCURRENT_EXECUTION_LIMIT=${concurrent_execution_limit}
      COMMAND_WHITELIST=${command_whitelist_json}
      COMMAND_WHITELIST_ALLOW_ALL=${command_whitelist_allow_all}
      | EOT
    order   => '10',
  }

  # Build docker run arguments
  $database_container_dir = dirname($database_path)
  $port_args = $ports.map |$host, $container| { "-p ${bind_address}:${host}:${container}" }.join(' ')
  $all_volumes = $volumes + ["${database_host_dir}:${database_container_dir}"]
  $volume_args = $all_volumes.map |$v| { "-v ${v}" }.join(' ')
  $env_args = $environment.map |$key, $value| { "-e ${key}=${value}" }.join(' ')

  $docker_run_args = [
    '--rm',
    "--name ${container_name}",
    "--env-file ${env_file_path}",
    $port_args,
    $volume_args,
    $env_args,
    $docker_extra_args,
    $image,
  ].filter |$arg| { $arg != '' }.join(' ')

  # Pull the image before starting the service
  $_pull_require = $manage_docker ? {
    true    => Service['docker'],
    default => [],
  }

  exec { "docker_pull_${container_name}":
    command => "${docker_bin} pull ${image}",
    path    => ['/usr/bin', '/bin'],
    unless  => "${docker_bin} image inspect ${image} > /dev/null 2>&1",
    require => $_pull_require,
  }

  $_restart_policy = $auto_restart ? {
    true    => 'on-failure',
    default => 'no',
  }

  # Create systemd service file
  file { "/etc/systemd/system/${container_name}.service":
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => @("EOT"),
      [Unit]
      Description=Pabawi Docker Container
      After=network-online.target docker.service
      Wants=network-online.target
      Requires=docker.service

      [Service]
      Type=simple
      ExecStartPre=-${docker_bin} stop ${container_name}
      ExecStartPre=-${docker_bin} rm ${container_name}
      ExecStart=${docker_bin} run ${docker_run_args}
      ExecStop=${docker_bin} stop ${container_name}
      Restart=${_restart_policy}
      RestartSec=10
      StandardOutput=journal
      StandardError=journal

      [Install]
      WantedBy=multi-user.target
      | EOT
    notify  => Exec["systemd_reload_${container_name}"],
  }

  # Reload systemd when service file changes
  exec { "systemd_reload_${container_name}":
    command     => 'systemctl daemon-reload',
    path        => ['/usr/bin', '/bin'],
    refreshonly => true,
  }

  # Manage the container service
  service { $container_name:
    ensure    => running,
    enable    => true,
    require   => [
      File["/etc/systemd/system/${container_name}.service"],
      Exec["docker_pull_${container_name}"],
      Exec["systemd_reload_${container_name}"],
      Concat['pabawi_env_file'],
    ],
    subscribe => [
      File["/etc/systemd/system/${container_name}.service"],
      Concat['pabawi_env_file'],
    ],
  }
}
