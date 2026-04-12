# @summary Configure Pabawi integration with Proxmox VE
#
# This class manages the integration between Pabawi and Proxmox Virtual Environment,
# including SSL certificate deployment and .env configuration for VM/LXC management.
#
# @param enabled
#   Whether the integration is enabled (sets PROXMOX_ENABLED in .env)
#
# @param settings
#   Hash of Pabawi application configuration settings written to .env with PROXMOX_ prefix.
#   Supported keys: host, port, token, username, password, realm,
#   ssl_reject_unauthorized, ssl_ca, ssl_cert, ssl_key, timeout, priority
#
# @param ssl_ca_source
#   Source URL for SSL CA certificate (supports file://, https://, or local path).
#   Deploys to path specified in settings['ssl_ca']
#
# @param ssl_cert_source
#   Source URL for SSL certificate (supports file://, https://, or local path).
#   Deploys to path specified in settings['ssl_cert']
#
# @param ssl_key_source
#   Source URL for SSL private key (supports file://, https://, or local path).
#   Deploys to path specified in settings['ssl_key']
#
# @example Basic usage with token authentication (recommended)
#   class { 'pabawi::integrations::proxmox':
#     settings => {
#       'host'  => 'proxmox.example.com',
#       'port'  => 8006,
#       'token' => 'user@pam!tokenid=token-value',
#     },
#   }
#
# @example With username/password and SSL certificates
#   class { 'pabawi::integrations::proxmox':
#     settings        => {
#       'host'                      => 'proxmox.example.com',
#       'port'                      => 8006,
#       'username'                  => 'root@pam',
#       'password'                  => 'secret',
#       'realm'                     => 'pam',
#       'ssl_reject_unauthorized'   => true,
#       'ssl_ca'                    => '/opt/pabawi/certs/proxmox/ca.pem',
#       'ssl_cert'                  => '/opt/pabawi/certs/proxmox/cert.pem',
#       'ssl_key'                   => '/opt/pabawi/certs/proxmox/key.pem',
#       'timeout'                   => 30000,
#       'priority'                  => 7,
#     },
#     ssl_ca_source   => 'file:///etc/ssl/certs/proxmox-ca.pem',
#     ssl_cert_source => 'file:///etc/ssl/certs/proxmox-cert.pem',
#     ssl_key_source  => 'file:///etc/ssl/private/proxmox-key.pem',
#   }
#
# @example Via Hiera
#   pabawi::integrations::proxmox::enabled: true
#   pabawi::integrations::proxmox::settings:
#     host: 'proxmox.example.com'
#     port: 8006
#     token: 'user@pam!tokenid=token-value'
#     ssl_reject_unauthorized: true
#     timeout: 30000
#
class pabawi::integrations::proxmox (
  Boolean $enabled = true,
  Hash $settings = {},
  Optional[String[1]] $ssl_ca_source = undef,
  Optional[String[1]] $ssl_cert_source = undef,
  Optional[String[1]] $ssl_key_source = undef,
) {
  # Merge sane defaults for SSL paths
  $_default_settings = {
    'ssl_ca'   => '/opt/pabawi/certs/proxmox/ca.pem',
    'ssl_cert' => '/opt/pabawi/certs/proxmox/cert.pem',
    'ssl_key'  => '/opt/pabawi/certs/proxmox/key.pem',
  }
  $_settings = $_default_settings + $settings

  # Deploy SSL certificates if sources are provided
  if $ssl_ca_source {
    $ssl_ca_path   = $_settings['ssl_ca']
    $ssl_ca_dir    = dirname($ssl_ca_path)
    $ssl_ca_parent = dirname($ssl_ca_dir)
    $ssl_ca_mode   = '0644'
    ensure_resource('file', $ssl_ca_parent, { ensure => directory, owner => 'root', group => 'root', mode => '0755' })
    ensure_resource('file', $ssl_ca_dir, { ensure => directory, owner => 'root', group => 'root', mode => '0755', require => File[$ssl_ca_parent] })

    # Handle file:// URLs
    if $ssl_ca_source =~ /^file:\/\/(.+)$/ {
      file { $ssl_ca_path:
        ensure  => file,
        source  => regsubst($ssl_ca_source, '^file://', ''),
        mode    => $ssl_ca_mode,
        owner   => 'root',
        group   => 'root',
        require => File[$ssl_ca_dir],
      }
    }
    # Handle https:// URLs
    elsif $ssl_ca_source =~ /^https:\/\/.+$/ {
      exec { 'download_proxmox_ssl_ca':
        command => "curl -sL -o ${ssl_ca_path} ${ssl_ca_source}",
        path    => ['/usr/bin', '/bin'],
        creates => $ssl_ca_path,
        require => File[$ssl_ca_dir],
      }
      -> file { $ssl_ca_path:
        ensure => file,
        mode   => $ssl_ca_mode,
        owner  => 'root',
        group  => 'root',
      }
    }
    # Handle direct file paths
    else {
      file { $ssl_ca_path:
        ensure  => file,
        source  => $ssl_ca_source,
        mode    => $ssl_ca_mode,
        owner   => 'root',
        group   => 'root',
        require => File[$ssl_ca_dir],
      }
    }
  }

  if $ssl_cert_source {
    $ssl_cert_path   = $_settings['ssl_cert']
    $ssl_cert_dir    = dirname($ssl_cert_path)
    $ssl_cert_parent = dirname($ssl_cert_dir)
    $ssl_cert_mode   = '0644'
    ensure_resource('file', $ssl_cert_parent, { ensure => directory, owner => 'root', group => 'root', mode => '0755' })
    ensure_resource('file', $ssl_cert_dir, { ensure => directory, owner => 'root', group => 'root', mode => '0755', require => File[$ssl_cert_parent] })

    # Handle file:// URLs
    if $ssl_cert_source =~ /^file:\/\/(.+)$/ {
      file { $ssl_cert_path:
        ensure  => file,
        source  => regsubst($ssl_cert_source, '^file://', ''),
        mode    => $ssl_cert_mode,
        owner   => 'root',
        group   => 'root',
        require => File[$ssl_cert_dir],
      }
    }
    # Handle https:// URLs
    elsif $ssl_cert_source =~ /^https:\/\/.+$/ {
      exec { 'download_proxmox_ssl_cert':
        command => "curl -sL -o ${ssl_cert_path} ${ssl_cert_source}",
        path    => ['/usr/bin', '/bin'],
        creates => $ssl_cert_path,
        require => File[$ssl_cert_dir],
      }
      -> file { $ssl_cert_path:
        ensure => file,
        mode   => $ssl_cert_mode,
        owner  => 'root',
        group  => 'root',
      }
    }
    # Handle direct file paths
    else {
      file { $ssl_cert_path:
        ensure  => file,
        source  => $ssl_cert_source,
        mode    => $ssl_cert_mode,
        owner   => 'root',
        group   => 'root',
        require => File[$ssl_cert_dir],
      }
    }
  }

  if $ssl_key_source {
    $ssl_key_path   = $_settings['ssl_key']
    $ssl_key_dir    = dirname($ssl_key_path)
    $ssl_key_parent = dirname($ssl_key_dir)
    $ssl_key_mode   = '0600'
    ensure_resource('file', $ssl_key_parent, { ensure => directory, owner => 'root', group => 'root', mode => '0755' })
    ensure_resource('file', $ssl_key_dir, { ensure => directory, owner => 'root', group => 'root', mode => '0755', require => File[$ssl_key_parent] })

    # Handle file:// URLs
    if $ssl_key_source =~ /^file:\/\/(.+)$/ {
      file { $ssl_key_path:
        ensure  => file,
        source  => regsubst($ssl_key_source, '^file://', ''),
        mode    => $ssl_key_mode,
        owner   => 'root',
        group   => 'root',
        require => File[$ssl_key_dir],
      }
    }
    # Handle https:// URLs
    elsif $ssl_key_source =~ /^https:\/\/.+$/ {
      exec { 'download_proxmox_ssl_key':
        command => "curl -sL -o ${ssl_key_path} ${ssl_key_source}",
        path    => ['/usr/bin', '/bin'],
        creates => $ssl_key_path,
        require => File[$ssl_key_dir],
      }
      -> file { $ssl_key_path:
        ensure => file,
        mode   => $ssl_key_mode,
        owner  => 'root',
        group  => 'root',
      }
    }
    # Handle direct file paths
    else {
      file { $ssl_key_path:
        ensure  => file,
        source  => $ssl_key_source,
        mode    => $ssl_key_mode,
        owner   => 'root',
        group   => 'root',
        require => File[$ssl_key_dir],
      }
    }
  }

  # Transform settings hash values to .env format
  # Arrays -> JSON, Booleans -> lowercase strings, Integers -> strings, undef/empty -> 'not-set'
  $env_vars = $_settings.reduce({}) |$memo, $pair| {
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
    $memo + { "PROXMOX_${env_key}" => $transformed }
  }

  # Build environment variable lines
  $env_lines = $env_vars.map |$key, $value| {
    "${key}=${value}"
  }.join("\n")

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_proxmox':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Proxmox Integration
      PROXMOX_ENABLED=${enabled}
      ${env_lines}
      | EOT
    order   => '26',
  }
}
