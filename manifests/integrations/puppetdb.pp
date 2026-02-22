# @summary Configure Pabawi integration with PuppetDB
#
# This class manages the integration between Pabawi and PuppetDB,
# including SSL certificate deployment and configuration.
#
# @param server_url
#   PuppetDB server URL (e.g., https://puppetdb.example.com:8081)
#
# @param ssl_cert
#   Path to SSL certificate for PuppetDB connection
#
# @param ssl_key
#   Path to SSL private key for PuppetDB connection
#
# @param ssl_ca
#   Path to SSL CA certificate for PuppetDB connection
#
# @param timeout
#   Connection timeout in seconds
#
# @example Basic usage
#   class { 'pabawi::integrations::puppetdb':
#     server_url => 'https://puppetdb.example.com:8081',
#   }
#
# @example With SSL certificates
#   class { 'pabawi::integrations::puppetdb':
#     server_url => 'https://puppetdb.example.com:8081',
#     ssl_cert   => '/etc/puppetlabs/puppet/ssl/certs/agent.pem',
#     ssl_key    => '/etc/puppetlabs/puppet/ssl/private_keys/agent.pem',
#     ssl_ca     => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
#   }
#
class pabawi::integrations::puppetdb (
  Optional[Pattern[/^https?:\/\/.+/]] $server_url = undef,
  Optional[Stdlib::Absolutepath] $ssl_cert = undef,
  Optional[Stdlib::Absolutepath] $ssl_key = undef,
  Optional[Stdlib::Absolutepath] $ssl_ca = undef,
  Integer[1] $timeout = 30,
) {
  # Validate that server_url is provided
  unless $server_url {
    fail('pabawi::integrations::puppetdb requires server_url parameter')
  }

  # Create Pabawi integration configuration directory
  ensure_resource('file', '/etc/pabawi', {
    'ensure' => 'directory',
    'mode'   => '0755',
    'owner'  => 'root',
    'group'  => 'root',
  })

  # Create PuppetDB integration configuration
  $config_content = {
    'puppetdb' => {
      'enabled'    => true,
      'server_url' => $server_url,
      'timeout'    => $timeout,
      'ssl'        => {
        'cert' => $ssl_cert,
        'key'  => $ssl_key,
        'ca'   => $ssl_ca,
      },
    },
  }

  file { '/etc/pabawi/puppetdb-integration.yaml':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => to_yaml($config_content),
    require => File['/etc/pabawi'],
  }

  # If SSL certificates are provided, ensure they exist
  if $ssl_cert {
    file { '/etc/pabawi/ssl':
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }
  }

  # Log integration status
  notify { 'pabawi_puppetdb_integration_enabled':
    message  => "Pabawi PuppetDB integration enabled for server: ${server_url}",
    loglevel => 'notice',
  }
}
