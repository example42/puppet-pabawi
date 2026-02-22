# Example: Full installation with all integrations enabled
#
# This example demonstrates a complete Pabawi setup with
# Bolt, PuppetDB, and Hiera integrations enabled.

class { 'pabawi':
  integrations => ['bolt', 'puppetdb', 'hiera'],
}

# Configure Bolt integration via Hiera or class parameters
class { 'pabawi::integrations::bolt':
  project_path         => '/opt/bolt-project',
  command_whitelist    => ['plan run', 'task run'],
  execution_timeout    => 300000,
  manage_package       => false,
}

# Configure PuppetDB integration
class { 'pabawi::integrations::puppetdb':
  server_url              => 'https://puppetdb.example.com:8081',
  ssl_ca_source           => 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem',
  ssl_cert_source         => 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem',
  ssl_key_source          => 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem',
  ssl_reject_unauthorized => true,
}

# Configure Hiera integration
class { 'pabawi::integrations::hiera':
  control_repo_path   => '/opt/control-repo',
  control_repo_source => 'https://github.com/example/control-repo.git',
  environments        => ['production', 'development'],
}
