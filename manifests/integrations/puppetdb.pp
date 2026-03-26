# @summary Configure Pabawi integration with PuppetDB
#
# This class manages the integration between Pabawi and PuppetDB,
# including SSL certificate deployment and .env configuration.
#
# @param enabled
#   Whether the integration is enabled (sets PUPPETDB_ENABLED in .env)
#
# @param settings
#   Hash of Pabawi application configuration settings written to .env with PUPPETDB_ prefix.
#   Supported keys: server_url, port, ssl_enabled, ssl_ca, ssl_cert, ssl_key, ssl_reject_unauthorized
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
#   class { 'pabawi::integrations::puppetdb':
#     settings => {
#       'server_url'                => 'https://puppetdb.example.com',
#       'port'                      => 8081,
#       'ssl_enabled'               => true,
#       'ssl_ca'                    => '/opt/pabawi/certs/ca.pem',
#       'ssl_cert'                  => '/opt/pabawi/certs/client.pem',
#       'ssl_key'                   => '/opt/pabawi/certs/client-key.pem',
#       'ssl_reject_unauthorized'   => true,
#     },
#   }
#
# @example With SSL certificates from sources
#   class { 'pabawi::integrations::puppetdb':
#     settings => {
#       'server_url'  => 'https://puppetdb.example.com',
#       'ssl_enabled' => true,
#       'ssl_ca'      => '/opt/pabawi/certs/puppetdb/ca.pem',
#       'ssl_cert'    => '/opt/pabawi/certs/puppetdb/cert.pem',
#       'ssl_key'     => '/opt/pabawi/certs/puppetdb/key.pem',
#     },
#     ssl_ca_source   => 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem',
#     ssl_cert_source => 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem',
#     ssl_key_source  => 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem',
#   }
#
class pabawi::integrations::puppetdb (
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
      fail('pabawi::integrations::puppetdb: settings[\'ssl_ca\'] is required when ssl_ca_source is provided')
    }
    if $ssl_cert_source and !$settings['ssl_cert'] {
      fail('pabawi::integrations::puppetdb: settings[\'ssl_cert\'] is required when ssl_cert_source is provided')
    }
    if $ssl_key_source and !$settings['ssl_key'] {
      fail('pabawi::integrations::puppetdb: settings[\'ssl_key\'] is required when ssl_key_source is provided')
    }
  }

  # Deploy SSL certificates if sources are provided
  if $ssl_ca_source {
    $ssl_ca_path = $settings['ssl_ca']
    $ssl_ca_mode = '0644'

    # Handle file:// URLs
    if $ssl_ca_source =~ /^file:\/\/(.+)$/ {
      file { $ssl_ca_path:
        ensure => file,
        source => regsubst($ssl_ca_source, '^file://', ''),
        mode   => $ssl_ca_mode,
        owner  => 'root',
        group  => 'root',
      }
    }
    # Handle https:// URLs
    elsif $ssl_ca_source =~ /^https:\/\/.+$/ {
      exec { 'download_puppetdb_ssl_ca':
        command => "curl -sL -o ${ssl_ca_path} ${ssl_ca_source}",
        path    => ['/usr/bin', '/bin'],
        creates => $ssl_ca_path,
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
        ensure => file,
        source => $ssl_ca_source,
        mode   => $ssl_ca_mode,
        owner  => 'root',
        group  => 'root',
      }
    }
  }

  if $ssl_cert_source {
    $ssl_cert_path = $settings['ssl_cert']
    $ssl_cert_mode = '0644'

    # Handle file:// URLs
    if $ssl_cert_source =~ /^file:\/\/(.+)$/ {
      file { $ssl_cert_path:
        ensure => file,
        source => regsubst($ssl_cert_source, '^file://', ''),
        mode   => $ssl_cert_mode,
        owner  => 'root',
        group  => 'root',
      }
    }
    # Handle https:// URLs
    elsif $ssl_cert_source =~ /^https:\/\/.+$/ {
      exec { 'download_puppetdb_ssl_cert':
        command => "curl -sL -o ${ssl_cert_path} ${ssl_cert_source}",
        path    => ['/usr/bin', '/bin'],
        creates => $ssl_cert_path,
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
        ensure => file,
        source => $ssl_cert_source,
        mode   => $ssl_cert_mode,
        owner  => 'root',
        group  => 'root',
      }
    }
  }

  if $ssl_key_source {
    $ssl_key_path = $settings['ssl_key']
    $ssl_key_mode = '0600'

    # Handle file:// URLs
    if $ssl_key_source =~ /^file:\/\/(.+)$/ {
      file { $ssl_key_path:
        ensure => file,
        source => regsubst($ssl_key_source, '^file://', ''),
        mode   => $ssl_key_mode,
        owner  => 'root',
        group  => 'root',
      }
    }
    # Handle https:// URLs
    elsif $ssl_key_source =~ /^https:\/\/.+$/ {
      exec { 'download_puppetdb_ssl_key':
        command => "curl -sL -o ${ssl_key_path} ${ssl_key_source}",
        path    => ['/usr/bin', '/bin'],
        creates => $ssl_key_path,
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
        ensure => file,
        source => $ssl_key_source,
        mode   => $ssl_key_mode,
        owner  => 'root',
        group  => 'root',
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
    $memo + { "PUPPETDB_${env_key}" => $transformed }
  }

  # Build environment variable lines
  $env_lines = $env_vars.map |$key, $value| {
    "${key}=${value}"
  }.join("\n")

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_puppetdb':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # PuppetDB Integration
      PUPPETDB_ENABLED=${enabled}
      ${env_lines}
      | EOT
    order   => '21',
  }
}
