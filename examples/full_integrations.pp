# Example: Puppet ecosystem setup
#
# Minimal configuration for a Puppet-centric deployment with Bolt,
# PuppetDB, Puppet Server, and Hiera. SSL certificates are sourced
# from the local Puppet agent. All other settings use defaults.
#
# For the full Hiera version with every integration, see
# hiera_full_integrations.yaml in this directory.

class { 'pabawi':
  integrations => ['bolt', 'puppetdb', 'puppetserver', 'hiera'],
}

# Bolt — clone project from git
class { 'pabawi::integrations::bolt':
  project_path_source => 'https://github.com/example/bolt-project.git',
}

# PuppetDB — deploy SSL certs from Puppet agent
class { 'pabawi::integrations::puppetdb':
  settings        => {
    'server_url'  => 'https://puppetdb.example.com',
    'port'        => 8081,
    'ssl_enabled' => true,
  },
  ssl_ca_source   => 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem',
  ssl_cert_source => 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem',
  ssl_key_source  => 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem',
}

# Puppet Server — reuse same certs
class { 'pabawi::integrations::puppetserver':
  settings        => {
    'server_url'  => 'https://puppet.example.com',
    'port'        => 8140,
    'ssl_enabled' => true,
  },
  ssl_ca_source   => 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem',
  ssl_cert_source => 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem',
  ssl_key_source  => 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem',
}

# Hiera — clone control repo from git
class { 'pabawi::integrations::hiera':
  settings            => {
    'config_path'  => 'hiera_pabawi.yaml',
    'environments' => ['production', 'development'],
  },
  control_repo_source => 'https://github.com/example/control-repo.git',
}
