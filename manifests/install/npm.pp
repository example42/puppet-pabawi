# @summary Install Pabawi from source using npm
#
# This class manages the installation of Pabawi from a git repository,
# including Node.js setup, dependency installation, and systemd service configuration.
#
# @param manage_nodejs
#   Whether to manage the nodejs and npm package installation. Set to false if Node.js is managed elsewhere.
#
# @param manage_git
#   Whether to manage the git package installation. Set to false if git is managed elsewhere.
#
# @param install_dir
#   Directory where Pabawi will be installed
#
# @param repo_url
#   Git repository URL for Pabawi source code
#
# @param version
#   Git branch, tag, or commit to checkout
#
# @param user
#   System user to run the Pabawi application
#
# @param group
#   System group for the Pabawi application
#
# @param npm_config
#   Additional npm configuration options
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
#   include pabawi::install::npm
#
# @example Custom installation directory
#   class { 'pabawi::install::npm':
#     install_dir => '/opt/custom/pabawi',
#     version     => 'v1.2.3',
#   }
#
class pabawi::install::npm (
  Boolean $manage_nodejs = true,
  Boolean $manage_git = true,
  Stdlib::Absolutepath $install_dir = '/opt/pabawi',
  String[1] $repo_url = 'https://github.com/example42/pabawi.git',
  String[1] $version = 'main',
  String[1] $user = 'pabawi',
  String[1] $group = 'pabawi',
  Hash $npm_config = {},
  String[1] $log_level = 'info',
  Boolean $auth_enabled = false,
  Optional[String[1]] $jwt_secret = undef,
  Stdlib::Absolutepath $database_path = '/var/lib/pabawi/pabawi.db',
  Integer $concurrent_execution_limit = 5,
) {
  # Validate auth configuration
  if $auth_enabled and !$jwt_secret {
    fail('pabawi::install::npm: jwt_secret is required when auth_enabled is true')
  }

  # Create application group
  group { $group:
    ensure => present,
    system => true,
  }

  # Create application user
  user { $user:
    ensure     => present,
    gid        => $group,
    home       => $install_dir,
    shell      => '/bin/bash',
    system     => true,
    managehome => false,
    require    => Group[$group],
  }

  # Ensure parent directory exists
  $parent_dir = dirname($install_dir)
  exec { "create_parent_dir_${install_dir}":
    command => "mkdir -p ${parent_dir}",
    path    => ['/usr/bin', '/bin'],
    creates => $parent_dir,
  }

  # Create installation directory
  file { $install_dir:
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '0755',
    require => [
      User[$user],
      Exec["create_parent_dir_${install_dir}"],
    ],
  }

  # Create backend directory for .env file
  file { "${install_dir}/backend":
    ensure  => directory,
    owner   => $user,
    group   => $group,
    mode    => '0755',
    require => File[$install_dir],
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
    owner  => $user,
    group  => $group,
    mode   => '0755',
  }

  # Create .env file using concat
  $env_file_path = "${install_dir}/backend/.env"
  concat { 'pabawi_env_file':
    path    => $env_file_path,
    owner   => $user,
    group   => $group,
    mode    => '0600',
    require => File["${install_dir}/backend"],
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

  # Conditionally manage Node.js and npm packages
  if $manage_nodejs {
    package { ['nodejs', 'npm']:
      ensure => installed,
    }
  }

  # Conditionally manage git package
  if $manage_git {
    package { 'git':
      ensure => installed,
    }
  }

  # Clone or update repository
  vcsrepo { $install_dir:
    ensure   => present,
    provider => git,
    source   => $repo_url,
    revision => $version,
    user     => $user,
    require  => [
      $manage_git ? {
        true    => Package['git'],
        default => undef,
      },
      File[$install_dir],
      User[$user],
    ].filter |$item| { $item =~ NotUndef },
  }

  # Install npm dependencies
  exec { 'pabawi_npm_install':
    command     => 'npm install',
    cwd         => $install_dir,
    path        => ['/usr/bin', '/bin', '/usr/local/bin'],
    user        => $user,
    environment => ["HOME=${install_dir}"],
    refreshonly => true,
    subscribe   => Vcsrepo[$install_dir],
    require     => [
      $manage_nodejs ? {
        true    => Package['nodejs', 'npm'],
        default => undef,
      },
      Vcsrepo[$install_dir],
    ].filter |$item| { $item =~ NotUndef },
  }

  # Build application
  exec { 'pabawi_npm_build':
    command     => 'npm run build',
    cwd         => $install_dir,
    path        => ['/usr/bin', '/bin', '/usr/local/bin'],
    user        => $user,
    environment => ["HOME=${install_dir}"],
    refreshonly => true,
    subscribe   => Exec['pabawi_npm_install'],
    require     => Exec['pabawi_npm_install'],
  }

  # Create systemd service file
  file { '/etc/systemd/system/pabawi.service':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => @("EOT"),
      [Unit]
      Description=Pabawi Application
      After=network.target

      [Service]
      Type=simple
      User=${user}
      Group=${group}
      WorkingDirectory=${install_dir}
      ExecStart=/usr/bin/node ${install_dir}/bin/pabawi
      Restart=on-failure
      RestartSec=10
      StandardOutput=journal
      StandardError=journal

      [Install]
      WantedBy=multi-user.target
      | EOT
    notify  => Exec['systemd_reload_pabawi'],
  }

  # Reload systemd when service file changes
  exec { 'systemd_reload_pabawi':
    command     => 'systemctl daemon-reload',
    path        => ['/usr/bin', '/bin'],
    refreshonly => true,
  }

  # Manage pabawi service
  service { 'pabawi':
    ensure    => running,
    enable    => true,
    require   => [
      File['/etc/systemd/system/pabawi.service'],
      Exec['pabawi_npm_build'],
      Exec['systemd_reload_pabawi'],
    ],
    subscribe => [
      Vcsrepo[$install_dir],
      File['/etc/systemd/system/pabawi.service'],
    ],
  }
}
