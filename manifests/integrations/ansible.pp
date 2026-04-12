# @summary Configure Pabawi integration with Ansible
#
# This class manages the integration between Pabawi and Ansible,
# including inventory and playbook management and .env configuration.
#
# @param enabled
#   Whether the integration is enabled (sets ANSIBLE_ENABLED in .env)
#
# @param settings
#   Hash of Pabawi application configuration settings written to .env with ANSIBLE_ prefix.
#   Supported keys: inventory_path, playbook_path, execution_timeout, config
#
# @param manage_package
#   Whether to install ansible package
#
# @param inventory_source
#   Git URL to clone inventory from (optional). Clones to settings['inventory_path']
#
# @param playbook_source
#   Git URL to clone playbooks from (optional). Clones to settings['playbook_path']
#
# @example Basic usage with settings hash
#   class { 'pabawi::integrations::ansible':
#     settings => {
#       'inventory_path'     => '/opt/pabawi/ansible/inventory',
#       'playbook_path'      => '/opt/pabawi/ansible/playbooks',
#       'execution_timeout'  => 300000,
#       'config'             => '/etc/ansible/ansible.cfg',
#     },
#   }
#
# @example Minimal usage with git repositories (paths default to /opt/pabawi/ansible/*)
#   class { 'pabawi::integrations::ansible':
#     inventory_source => 'https://github.com/example/ansible-inventory.git',
#     playbook_source  => 'https://github.com/example/ansible-playbooks.git',
#   }
#
class pabawi::integrations::ansible (
  Boolean $enabled = true,
  Hash $settings = {},
  Boolean $manage_package = false,
  Optional[String[1]] $inventory_source = undef,
  Optional[String[1]] $playbook_source = undef,
) {
  # Merge sane defaults for local paths when source is provided but path is not
  $_default_settings = {
    'inventory_path' => '/opt/pabawi/ansible/inventory',
    'playbook_path'  => '/opt/pabawi/ansible/playbooks',
  }
  $_settings = $_default_settings + $settings

  # Manage ansible package if requested
  if $manage_package {
    package { 'ansible':
      ensure => installed,
    }
  }

  # Clone inventory repository if source is provided
  if $inventory_source {
    $inventory_path = $_settings['inventory_path']
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
  if $playbook_source {
    $playbook_path = $_settings['playbook_path']
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

  # Transform settings hash values to .env format
  # Arrays -> JSON, Booleans -> lowercase strings, Integers -> strings, undef/empty -> 'not-set'
  $env_vars = $_settings.reduce({}) |$memo, $pair| {
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
    $memo + { "ANSIBLE_${env_key}" => $transformed }
  }

  # Build environment variable lines
  $env_lines = $env_vars.map |$key, $value| {
    "${key}=${value}"
  }.join("\n")

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_ansible':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # Ansible Integration
      ANSIBLE_ENABLED=${enabled}
      ${env_lines}
      | EOT
    order   => '24',
  }
}
