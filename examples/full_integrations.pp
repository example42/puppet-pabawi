# Example: Full installation with all integrations enabled
#
# This example demonstrates a complete Pabawi setup with
# Bolt and PuppetDB integrations enabled.

class { 'pabawi':
  bolt_enable     => true,
  puppetdb_enable => true,
  integrations    => {
    'terraform' => true,
    'custom'    => true,
  },
}

class { 'pabawi::integrations::bolt':
  project_path  => '/opt/bolt-project',
  bolt_settings => {
    'timeout'     => 300,
    'concurrency' => 10,
  },
}

class { 'pabawi::integrations::puppetdb':
  server_url => 'https://puppetdb.example.com:8081',
  ssl_cert   => '/etc/puppetlabs/puppet/ssl/certs/agent.pem',
  ssl_key    => '/etc/puppetlabs/puppet/ssl/private_keys/agent.pem',
  ssl_ca     => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
  timeout    => 60,
}
