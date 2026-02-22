# @summary Configure Pabawi integration with Puppet Server
#
# This class manages the integration between Pabawi and Puppet Server,
# including SSL certificate deployment and .env configuration.
#
# @param enabled
#   Whether this integration is enabled (managed by main class)
#
# @param server_url
#   Puppet Server URL (e.g., https://puppet.example.com)
#
# @param port
#   Puppet Server port
#
# @param ssl_enabled
#   Whether to use SSL for Puppet Server connection
#
# @param ssl_ca
#   Path to SSL CA certificate (used in .env file)
#
# @param ssl_cert
#   Path to SSL certificate (used in .env file)
#
# @param ssl_key
#   Path to SSL private key (used in .env file)
#
# @param ssl_ca_source
#   Source URL for SSL CA certificate (supports file://, https://, or local path)
#
# @param ssl_cert_source
#   Source URL for SSL certificate (supports file://, https://, or local path)
#
# @param ssl_key_source
#   Source URL for SSL private key (supports file://, https://, or local path)
#
# @param ssl_reject_unauthorized
#   Whether to reject unauthorized SSL certificates
#
# @param inactivity_threshold
#   Node inactivity threshold in seconds
#
# @param cache_ttl
#   Cache time-to-live in milliseconds
#
# @param circuit_breaker_threshold
#   Number of failures before circuit breaker opens
#
# @param circuit_breaker_timeout
#   Circuit breaker timeout in milliseconds
#
# @param circuit_breaker_reset_timeout
#   Circuit breaker reset timeout in milliseconds
#
# @example Basic usage
#   class { 'pabawi':
#     integrations => {
#       'puppetserver' => {
#         'enabled' => true,
#         'server_url' => 'https://puppet.example.com',
#       },
#     },
#   }
#
class pabawi::integrations::puppetserver (
  Boolean $enabled = false,
  Optional[String[1]] $server_url = undef,
  Integer $port = 8140,
  Boolean $ssl_enabled = true,
  Optional[String[1]] $ssl_ca = undef,
  Optional[String[1]] $ssl_cert = undef,
  Optional[String[1]] $ssl_key = undef,
  Optional[String[1]] $ssl_ca_source = undef,
  Optional[String[1]] $ssl_cert_source = undef,
  Optional[String[1]] $ssl_key_source = undef,
  Boolean $ssl_reject_unauthorized = true,
  Integer $inactivity_threshold = 3600,
  Integer $cache_ttl = 300000,
  Integer $circuit_breaker_threshold = 5,
  Integer $circuit_breaker_timeout = 60000,
  Integer $circuit_breaker_reset_timeout = 30000,
) {
  # Validate required parameters
  unless $server_url {
    fail('pabawi::integrations::puppetserver requires server_url parameter')
  }

  # Create SSL directory for Puppet Server certificates
  ensure_resource('file', '/etc/pabawi/ssl', {
    'ensure' => 'directory',
    'mode'   => '0755',
    'owner'  => 'root',
    'group'  => 'root',
  })

  file { '/etc/pabawi/ssl/puppetserver':
    ensure => directory,
    mode   => '0755',
    owner  => 'root',
    group  => 'root',
  }

  # Helper function to handle SSL file sources
  $ssl_files = {
    'ca'   => { 'source' => $ssl_ca_source, 'path' => $ssl_ca },
    'cert' => { 'source' => $ssl_cert_source, 'path' => $ssl_cert },
    'key'  => { 'source' => $ssl_key_source, 'path' => $ssl_key },
  }

  $ssl_paths = $ssl_files.reduce({}) |$memo, $item| {
    $name = $item[0]
    $source = $item[1]['source']
    $target_path = $item[1]['path']

    if $source {
      $dest_path = "/etc/pabawi/ssl/puppetserver/${name}.pem"
      $mode = $name ? {
        'key'   => '0600',
        default => '0644',
      }

      # Handle file:// URLs
      if $source =~ /^file:\/\/(.+)$/ {
        $source_path = $1
        file { $dest_path:
          ensure => file,
          source => $source_path,
          mode   => $mode,
          owner  => 'root',
          group  => 'root',
        }
      }
      # Handle https:// URLs
      elsif $source =~ /^https:\/\/.+$/ {
        exec { "download_puppetserver_${name}":
          command => "curl -sL -o ${dest_path} ${source}",
          path    => ['/usr/bin', '/bin'],
          creates => $dest_path,
        }
        -> file { $dest_path:
          ensure => file,
          mode   => $mode,
          owner  => 'root',
          group  => 'root',
        }
      }
      # Handle direct file paths
      else {
        file { $dest_path:
          ensure => file,
          source => $source,
          mode   => $mode,
          owner  => 'root',
          group  => 'root',
        }
      }

      $memo + { $name => $dest_path }
    } elsif $target_path {
      # Use the provided path directly if no source
      $memo + { $name => $target_path }
    } else {
      $memo + { $name => '' }
    }
  }

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_puppetserver':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Puppet Server Integration
      PUPPETSERVER_ENABLED=${enabled}
      PUPPETSERVER_SERVER_URL=${server_url}
      PUPPETSERVER_PORT=${port}
      PUPPETSERVER_SSL_ENABLED=${ssl_enabled}
      PUPPETSERVER_SSL_CA=${ssl_paths['ca']}
      PUPPETSERVER_SSL_CERT=${ssl_paths['cert']}
      PUPPETSERVER_SSL_KEY=${ssl_paths['key']}
      PUPPETSERVER_SSL_REJECT_UNAUTHORIZED=${ssl_reject_unauthorized}
      PUPPETSERVER_INACTIVITY_THRESHOLD=${inactivity_threshold}
      PUPPETSERVER_CACHE_TTL=${cache_ttl}
      PUPPETSERVER_CIRCUIT_BREAKER_THRESHOLD=${circuit_breaker_threshold}
      PUPPETSERVER_CIRCUIT_BREAKER_TIMEOUT=${circuit_breaker_timeout}
      PUPPETSERVER_CIRCUIT_BREAKER_RESET_TIMEOUT=${circuit_breaker_reset_timeout}
      | EOT
    order   => '22',
  }
}
