# @summary Configure Pabawi integration with Puppet Server
#
# This class manages the integration between Pabawi and Puppet Server,
# including SSL certificate deployment and .env configuration.
#
# @param enabled
#   Whether the integration is enabled (sets PUPPETSERVER_ENABLED in .env)
#
# @param settings
#   Hash of Pabawi application configuration settings written to .env with PUPPETSERVER_ prefix.
#   Supported keys: server_url, port, ssl_enabled, ssl_ca, ssl_cert, ssl_key, ssl_reject_unauthorized,
#   inactivity_threshold, cache_ttl, circuit_breaker_threshold, circuit_breaker_timeout, circuit_breaker_reset_timeout
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
# @example Basic usage with settings hash
#   class { 'pabawi::integrations::puppetserver':
#     settings => {
#       'server_url'                      => 'https://puppet.example.com',
#       'port'                            => 8140,
#       'ssl_enabled'                     => true,
#       'ssl_ca'                          => '/opt/pabawi/certs/ca.pem',
#       'ssl_cert'                        => '/opt/pabawi/certs/client.pem',
#       'ssl_key'                         => '/opt/pabawi/certs/client-key.pem',
#       'ssl_reject_unauthorized'         => true,
#       'inactivity_threshold'            => 3600,
#       'cache_ttl'                       => 300000,
#       'circuit_breaker_threshold'       => 5,
#       'circuit_breaker_timeout'         => 60000,
#       'circuit_breaker_reset_timeout'   => 30000,
#     },
#   }
#
# @example With SSL certificates from sources
#   class { 'pabawi::integrations::puppetserver':
#     settings => {
#       'server_url'  => 'https://puppet.example.com',
#       'ssl_enabled' => true,
#       'ssl_ca'      => '/opt/pabawi/certs/puppetserver/ca.pem',
#       'ssl_cert'    => '/opt/pabawi/certs/puppetserver/cert.pem',
#       'ssl_key'     => '/opt/pabawi/certs/puppetserver/key.pem',
#     },
#     ssl_ca_source   => 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem',
#     ssl_cert_source => 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem',
#     ssl_key_source  => 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem',
#   }
#
class pabawi::integrations::puppetserver (
  Boolean $enabled = true,
  Hash $settings = {},
  Optional[String[1]] $ssl_ca_source = undef,
  Optional[String[1]] $ssl_cert_source = undef,
  Optional[String[1]] $ssl_key_source = undef,
) {
  # Validate required parameters when integration is enabled
  if $enabled {
    # Source-path consistency validation
    if $ssl_ca_source and !$settings['ssl_ca'] {
      fail('pabawi::integrations::puppetserver: settings[\'ssl_ca\'] is required when ssl_ca_source is provided')
    }
    if $ssl_cert_source and !$settings['ssl_cert'] {
      fail('pabawi::integrations::puppetserver: settings[\'ssl_cert\'] is required when ssl_cert_source is provided')
    }
    if $ssl_key_source and !$settings['ssl_key'] {
      fail('pabawi::integrations::puppetserver: settings[\'ssl_key\'] is required when ssl_key_source is provided')
    }

    # SSL configuration validation - all three SSL sources should be provided together
    $ssl_sources_provided = [$ssl_ca_source, $ssl_cert_source, $ssl_key_source].filter |$val| { $val != undef }
    if $ssl_sources_provided.length > 0 and $ssl_sources_provided.length < 3 {
      fail('pabawi::integrations::puppetserver: When SSL certificates are used, all three SSL sources (ssl_ca_source, ssl_cert_source, ssl_key_source) must be provided together')
    }
  }

  # Deploy SSL certificates if sources are provided
  if $ssl_ca_source {
    $ssl_ca_path   = $settings['ssl_ca']
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
      exec { 'download_puppetserver_ssl_ca':
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
    $ssl_cert_path   = $settings['ssl_cert']
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
      exec { 'download_puppetserver_ssl_cert':
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
    $ssl_key_path   = $settings['ssl_key']
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
      exec { 'download_puppetserver_ssl_key':
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
    $memo + { "PUPPETSERVER_${env_key}" => $transformed }
  }

  # Build environment variable lines
  $env_lines = $env_vars.map |$key, $value| {
    "${key}=${value}"
  }.join("\n")

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_puppetserver':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Puppet Server Integration
      PUPPETSERVER_ENABLED=${enabled}
      ${env_lines}
      | EOT
    order   => '22',
  }
}
