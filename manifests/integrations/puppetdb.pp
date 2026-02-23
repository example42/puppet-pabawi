# @summary Configure Pabawi integration with PuppetDB
#
# This class manages the integration between Pabawi and PuppetDB,
# including SSL certificate deployment and .env configuration.
#
# @param enabled
#   Whether the integration is enabled (sets PUPPETDB_ENABLED in .env)
#
# @param server_url
#   PuppetDB server URL (e.g., https://puppetdb.example.com)
#
# @param port
#   PuppetDB server port
#
# @param ssl_enabled
#   Whether to use SSL for PuppetDB connection
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
# @example Basic usage
#   class { 'pabawi':
#     integrations => ['puppetdb'],
#   }
#
#   # Configure via Hiera
#   pabawi::integrations::puppetdb::server_url: 'https://puppetdb.example.com'
#
# @example With SSL certificates from sources
#   class { 'pabawi':
#     integrations => ['puppetdb'],
#   }
#
#   # Configure via Hiera
#   pabawi::integrations::puppetdb::server_url: 'https://puppetdb.example.com'
#   pabawi::integrations::puppetdb::ssl_ca: '/etc/pabawi/ssl/puppetdb/ca.pem'
#   pabawi::integrations::puppetdb::ssl_cert: '/etc/pabawi/ssl/puppetdb/cert.pem'
#   pabawi::integrations::puppetdb::ssl_key: '/etc/pabawi/ssl/puppetdb/key.pem'
#   pabawi::integrations::puppetdb::ssl_ca_source: 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem'
#   pabawi::integrations::puppetdb::ssl_cert_source: 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem'
#   pabawi::integrations::puppetdb::ssl_key_source: 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem'
#
class pabawi::integrations::puppetdb (
  Boolean $enabled = true,
  Optional[Stdlib::HTTPUrl] $server_url = undef,
  Integer $port = 8081,
  Boolean $ssl_enabled = true,
  Optional[String[1]] $ssl_ca = undef,
  Optional[String[1]] $ssl_cert = undef,
  Optional[String[1]] $ssl_key = undef,
  Optional[String[1]] $ssl_ca_source = undef,
  Optional[String[1]] $ssl_cert_source = undef,
  Optional[String[1]] $ssl_key_source = undef,
  Boolean $ssl_reject_unauthorized = true,
) {
  # Validate required parameters
  unless $server_url {
    fail('pabawi::integrations::puppetdb requires server_url parameter')
  }

  # Create SSL directory for PuppetDB certificates
  ensure_resource('file', '/etc/pabawi/ssl', {
    'ensure' => 'directory',
    'mode'   => '0755',
    'owner'  => 'root',
    'group'  => 'root',
  })

  file { '/etc/pabawi/ssl/puppetdb':
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
      $dest_path = "/etc/pabawi/ssl/puppetdb/${name}.pem"
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
        exec { "download_puppetdb_${name}":
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
  concat::fragment { 'pabawi_env_puppetdb':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # PuppetDB Integration
      PUPPETDB_ENABLED=${enabled}
      PUPPETDB_SERVER_URL=${server_url}
      PUPPETDB_PORT=${port}
      PUPPETDB_SSL_ENABLED=${ssl_enabled}
      PUPPETDB_SSL_CA=${ssl_paths['ca']}
      PUPPETDB_SSL_CERT=${ssl_paths['cert']}
      PUPPETDB_SSL_KEY=${ssl_paths['key']}
      PUPPETDB_SSL_REJECT_UNAUTHORIZED=${ssl_reject_unauthorized}
      | EOT
    order   => '21',
  }
}
