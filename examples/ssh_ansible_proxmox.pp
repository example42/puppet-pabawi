# Example: Agentless infrastructure with SSH, Ansible, and Proxmox
#
# This setup is for environments without Puppet agents where you manage
# nodes via SSH and Ansible, and provision VMs/LXCs on Proxmox.

class { 'pabawi':
  integrations => ['ssh', 'ansible', 'proxmox'],
}

# SSH — direct execution with connection pool
class { 'pabawi::integrations::ssh':
  settings => {
    'default_user'             => 'automation',
    'default_port'             => 22,
    'default_key'              => '/opt/pabawi/ssh/id_ed25519',
    'host_key_check'           => true,
    'connection_timeout'       => 30,
    'command_timeout'          => 300,
    'max_connections'          => 50,
    'max_connections_per_host' => 5,
    'concurrency_limit'        => 10,
  },
}

# Ansible — clone inventory and playbooks from git
class { 'pabawi::integrations::ansible':
  manage_package   => true,
  settings         => {
    'inventory_path'    => '/opt/pabawi/ansible/inventory',
    'playbook_path'     => '/opt/pabawi/ansible/playbooks',
    'execution_timeout' => 300000,
  },
  inventory_source => 'https://github.com/example/ansible-inventory.git',
  playbook_source  => 'https://github.com/example/ansible-playbooks.git',
}

# Proxmox — token authentication (recommended)
class { 'pabawi::integrations::proxmox':
  settings => {
    'host'                    => 'proxmox.example.com',
    'port'                    => 8006,
    'token'                   => 'automation@pve!pabawi=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx',
    'ssl_reject_unauthorized' => true,
    'timeout'                 => 30000,
  },
}
