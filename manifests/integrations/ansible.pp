# @summary Configure Pabawi integration with Ansible
#
# This class manages the integration between Pabawi and Ansible,
# including inventory and playbook management and .env configuration.
#
# @param enabled
#   Whether the integration is enabled (sets ANSIBLE_ENABLED in .env)
#
# @param manage_package
#   Whether to install ansible package
#
# @param inventory_path
#   Local path for ansible inventory
#
# @param inventory_source
#   Git URL to clone inventory from (optional)
#
# @param playbook_path
#   Local path for ansible playbooks
#
# @param playbook_source
#   Git URL to clone playbooks from (optional)
#
# @param execution_timeout
#   Timeout for ansible command execution in milliseconds
#
# @param config
#   Path to ansible configuration file (optional)
#
# @example Basic usage
#   class { 'pabawi':
#     integrations => ['ansible'],
#   }
#
#   # Configure via Hiera
#   pabawi::integrations::ansible::inventory_path: '/etc/ansible/inventory'
#   pabawi::integrations::ansible::playbook_path: '/etc/ansible/playbooks'
#
# @example With git repositories
#   class { 'pabawi':
#     integrations => ['ansible'],
#   }
#
#   # Configure via Hiera
#   pabawi::integrations::ansible::inventory_path: '/etc/ansible/inventory'
#   pabawi::integrations::ansible::inventory_source: 'https://github.com/example/ansible-inventory.git'
#   pabawi::integrations::ansible::playbook_path: '/etc/ansible/playbooks'
#   pabawi::integrations::ansible::playbook_source: 'https://github.com/example/ansible-playbooks.git'
#
class pabawi::integrations::ansible (
  Boolean $enabled = true,
  Boolean $manage_package = false,
  Optional[Stdlib::Absolutepath] $inventory_path = undef,
  Optional[String[1]] $inventory_source = undef,
  Optional[Stdlib::Absolutepath] $playbook_path = undef,
  Optional[String[1]] $playbook_source = undef,
  Integer $execution_timeout = 300000,
  Optional[Stdlib::Absolutepath] $config = undef,
) {
  # Validate required parameters
  unless $inventory_path {
    fail('pabawi::integrations::ansible requires inventory_path parameter')
  }

  # Manage ansible package if requested
  if $manage_package {
    package { 'ansible':
      ensure => installed,
    }
  }

  # Clone inventory repository if source is provided
  if $inventory_source {
    # Ensure parent directory exists
    $inventory_parent_dir = dirname($inventory_path)
    exec { "create_ansible_inventory_parent_dir_${inventory_path}":
      command => "mkdir -p ${inventory_parent_dir}",
      path    => ['/usr/bin', '/bin'],
      creates => $inventory_parent_dir,
    }

    vcsrepo { $inventory_path:
      ensure   => present,
      provider => git,
      source   => $inventory_source,
      require  => Exec["create_ansible_inventory_parent_dir_${inventory_path}"],
    }
  }

  # Clone playbook repository if source is provided
  if $playbook_source and $playbook_path {
    # Ensure parent directory exists
    $playbook_parent_dir = dirname($playbook_path)
    exec { "create_ansible_playbook_parent_dir_${playbook_path}":
      command => "mkdir -p ${playbook_parent_dir}",
      path    => ['/usr/bin', '/bin'],
      creates => $playbook_parent_dir,
    }

    vcsrepo { $playbook_path:
      ensure   => present,
      provider => git,
      source   => $playbook_source,
      require  => Exec["create_ansible_playbook_parent_dir_${playbook_path}"],
    }
  }

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_ansible':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Ansible Integration
      ANSIBLE_ENABLED=${enabled}
      ANSIBLE_INVENTORY_PATH=${inventory_path}
      ANSIBLE_PLAYBOOK_PATH=${pick($playbook_path, '')}
      ANSIBLE_EXECUTION_TIMEOUT=${execution_timeout}
      ANSIBLE_CONFIG=${pick($config, '')}
      | EOT
    order   => '24',
  }
}
