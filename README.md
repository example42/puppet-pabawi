# Pabawi Puppet Module

Puppet module for managing Pabawi - a unified interface for Puppet ecosystem tools.

## Table of Contents

- [Description](#description)
- [Setup](#setup)
  - [Requirements](#requirements)
  - [Installation](#installation)
- [Usage](#usage)
  - [Basic Usage](#basic-usage)
  - [Installation Methods](#installation-methods)
  - [Proxy Configuration](#proxy-configuration)
  - [Integration Configuration](#integration-configuration)
- [Configuration Details](#configuration-details)
  - [Environment File (.env)](#environment-file-env)
  - [Content Sources](#content-sources)
  - [Package Management](#package-management)
  - [SSL Certificate Management](#ssl-certificate-management)
- [Integration Reference](#integration-reference)
  - [Bolt](#bolt-integration)
  - [Ansible](#ansible-integration)
  - [PuppetDB](#puppetdb-integration)
  - [Puppet Server](#puppet-server-integration)
  - [Hiera](#hiera-integration)
  - [SSH](#ssh-integration)
  - [Proxmox](#proxmox-integration)
  - [AWS](#aws-integration)
- [Examples](#examples)
- [Reference](#reference)
- [Limitations](#limitations)
- [Development](#development)

## Description

Pabawi is a unified web interface for interacting with various Puppet ecosystem tools including Bolt, PuppetDB, Puppet Server, Hiera, Ansible, SSH, Proxmox, and AWS. This Puppet module manages the installation and configuration of Pabawi and its integrations.

**Key Features:**
- `.env` file-based configuration for all integrations
- Support for git repository cloning (projects, inventories, control repos)
- Flexible SSL certificate management (local files, file:// URLs, https:// URLs)
- Optional package management for tools (Bolt, Ansible, Hiera)
- Multiple installation methods (npm, Docker)
- Nginx reverse proxy with SSL support

## Setup

### Requirements

- Puppet 6.0 or higher
- puppetlabs/stdlib
- puppetlabs/concat
- puppetlabs/vcsrepo
- puppet/nginx (for nginx proxy)
- puppetlabs/docker (for docker installation method)

### Installation

Add this module to your Puppetfile:

```puppet
mod 'pabawi',
  :git => 'https://github.com/example42/puppet-pabawi.git'
```

Or install manually:

```bash
puppet module install example42-pabawi
```

## Usage

### Basic Usage

Include the module with default settings:

```puppet
include pabawi
```

This will:
- Install Pabawi using npm (default installation method)
- Configure nginx as a reverse proxy with self-signed SSL
- Set up integrations based on Hiera configuration
- Generate `.env` file at `/opt/pabawi/backend/.env` (npm) or `/opt/pabawi/.env` (docker)

### Installation Methods

#### NPM Installation (Default)

```puppet
class { 'pabawi':
  install_class => 'pabawi::install::npm',
}
```

**Features:**
- Clones source from git repository
- Runs `npm install` and `npm run build`
- Creates systemd service
- Generates `.env` file at `${install_dir}/backend/.env`

#### Docker Installation

```puppet
class { 'pabawi':
  install_class => 'pabawi::install::docker',
}
```

**Features:**
- Pulls Docker image
- Mounts `.env` file into container
- Configures automatic restart
- Generates `.env` file at `${install_dir}/.env`

### Proxy Configuration

#### Nginx Proxy (Default)

```puppet
class { 'pabawi':
  proxy_class => 'pabawi::proxy::nginx',
}
```

#### Disable Proxy Management

```puppet
class { 'pabawi':
  proxy_manage => false,
}
```

### Integration Configuration

Integrations are configured via Hiera using a simple array of enabled integration names. Integration-specific parameters are configured via standard Puppet class parameters.

**Example:**

```yaml
# Enable integrations by listing them in the array
pabawi::integrations:
  - bolt
  - puppetdb

# Configure each integration via class parameters using settings hash
pabawi::integrations::bolt::settings:
  project_path: '/opt/bolt-project'
  execution_timeout: 300000

pabawi::integrations::puppetdb::settings:
  server_url: 'https://puppetdb.example.com'
  port: 8081
  ssl_enabled: true
pabawi::integrations::puppetdb::ssl_ca_source: 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem'
```

This approach provides:
- **Single source of truth**: Presence in array = enabled, absence = disabled
- **Standard Puppet patterns**: Use class parameters for configuration
- **Cleaner Hiera data**: No nested hashes with `enabled` keys
- **Easier to understand**: Simple array syntax

#### Two-Level Integration Control

Each integration supports two levels of control:

1. **Array Inclusion** - Controls whether the integration class is included (resources created, .env fragment added)
2. **`enabled` Parameter** - Controls whether the integration is active in Pabawi (sets `*_ENABLED` in .env)

This allows you to pre-configure integrations without enabling them, making it easy to toggle integrations on/off without modifying the array or losing configuration.

**Usage Pattern:**

```yaml
# Include bolt integration (creates resources, adds .env fragment)
pabawi::integrations:
  - bolt

# Configure and control enabled state
pabawi::integrations::bolt::enabled: true  # or false to disable
pabawi::integrations::bolt::settings:
  project_path: '/opt/bolt-project'
```

**Benefits:**

- ✅ **Pre-configuration**: Set up integrations without enabling them
- ✅ **Easy toggling**: Change `enabled: false` to `enabled: true` without array modification
- ✅ **Staged rollout**: Configure everything, enable selectively
- ✅ **Testing**: Disable integrations temporarily without losing configuration

**Example - Disabled Integration:**

```yaml
# Include integration but disable it
pabawi::integrations:
  - bolt

pabawi::integrations::bolt::enabled: false  # Disabled but configured
pabawi::integrations::bolt::settings:
  project_path: '/opt/bolt-project'
  execution_timeout: 300000
```

This generates `.env` with `BOLT_ENABLED=false`, allowing you to enable it later by simply changing the parameter to `true`.

## Configuration Details

### Environment File (.env)

All integrations write their configuration to a single `.env` file using Puppet's `concat` module. The file structure:

```
# Base Configuration (order: 10)
LOG_LEVEL=info
AUTH_ENABLED=true
JWT_SECRET=...
DATABASE_PATH=...
CONCURRENT_EXECUTION_LIMIT=10

# Bolt Integration (order: 20)
BOLT_ENABLED=true
BOLT_PROJECT_PATH=/opt/bolt-project
...

# PuppetDB Integration (order: 21)
PUPPETDB_ENABLED=true
PUPPETDB_SERVER_URL=https://puppetdb.example.com
...

# Puppet Server Integration (order: 22)
PUPPETSERVER_ENABLED=true
...

# Hiera Integration (order: 23)
HIERA_ENABLED=true
...

# Ansible Integration (order: 24)
ANSIBLE_ENABLED=true
...

# SSH Integration (order: 25)
SSH_ENABLED=true
...

# Proxmox Integration (order: 26)
PROXMOX_ENABLED=true
...

# AWS Integration (order: 27)
AWS_ENABLED=true
...
```

### Content Sources

The module supports cloning git repositories and downloading files from various sources:

#### Git Repository Sources

For directory-based content (Bolt projects, Ansible inventories, Hiera control repos):

```yaml
pabawi::integrations:
  - bolt

pabawi::integrations::bolt::settings:
  project_path: '/opt/bolt-project'
pabawi::integrations::bolt::project_path_source: 'https://github.com/example/bolt-project.git'
```

Uses `vcsrepo` module to clone the repository to the specified path.

#### File Sources

For SSL certificates and keys, supports multiple URL schemes:

**Local file paths:**
```yaml
ssl_ca: '/etc/puppetlabs/puppet/ssl/certs/ca.pem'
```

**file:// URLs:**
```yaml
ssl_ca_source: 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem'
```

**https:// URLs:**
```yaml
ssl_ca_source: 'https://example.com/certs/ca.pem'
```

When `*_source` parameters are provided, files are downloaded/copied to `/etc/pabawi/ssl/<integration>/` directory.

### Package Management

Integrations that require external tools (Bolt, Ansible, Hiera) support optional package management:

```yaml
pabawi::integrations:
  - bolt

pabawi::integrations::bolt::manage_package: true  # Installs puppet-bolt package
pabawi::integrations::bolt::settings:
  project_path: '/opt/bolt-project'
```

**Note:** PuppetDB and Puppet Server integrations don't manage packages as they're external services.

### SSL Certificate Management

SSL certificates are managed per-integration with automatic file permissions:

- **CA certificates:** 0644 (readable by all)
- **Client certificates:** 0644 (readable by all)
- **Private keys:** 0600 (readable by owner only)

Files are stored in `/etc/pabawi/ssl/<integration>/` directories.

## Integration Reference

### Bolt Integration

Manages Puppet Bolt project configuration.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | Boolean | true | Whether the integration is enabled (sets BOLT_ENABLED in .env) |
| `settings` | Hash | {} | Hash of configuration settings (see below) |
| `manage_package` | Boolean | false | Install puppet-bolt package |
| `project_path_source` | String | undef | Git URL to clone project from |

**Settings Hash Keys:**

| Key | Type | Description |
|-----|------|-------------|
| `project_path` | String | Local path for Bolt project (required) |
| `execution_timeout` | Integer | Command timeout in milliseconds |

**Example:**

```yaml
# Enable Bolt integration
pabawi::integrations:
  - bolt

# Configure Bolt parameters
pabawi::integrations::bolt::manage_package: true
pabawi::integrations::bolt::settings:
  project_path: '/opt/bolt-project'
  execution_timeout: 300000
pabawi::integrations::bolt::project_path_source: 'https://github.com/example/bolt-project.git'
```

**Generated .env entries:**
```
BOLT_ENABLED=true
BOLT_PROJECT_PATH=/opt/bolt-project
BOLT_EXECUTION_TIMEOUT=300000
```

### Ansible Integration

Manages Ansible inventory and playbook configuration.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | Boolean | true | Whether the integration is enabled (sets ANSIBLE_ENABLED in .env) |
| `settings` | Hash | {} | Hash of configuration settings (see below) |
| `manage_package` | Boolean | false | Install ansible package |
| `inventory_source` | String | undef | Git URL to clone inventory from |
| `playbook_source` | String | undef | Git URL to clone playbooks from |

**Settings Hash Keys:**

| Key | Type | Description |
|-----|------|-------------|
| `inventory_path` | String | Local path for inventory (required) |
| `playbook_path` | String | Local path for playbooks |
| `execution_timeout` | Integer | Command timeout in milliseconds |
| `config` | String | Path to ansible.cfg file |

**Example:**

```yaml
# Enable Ansible integration
pabawi::integrations:
  - ansible

# Configure Ansible parameters
pabawi::integrations::ansible::manage_package: true
pabawi::integrations::ansible::settings:
  inventory_path: '/etc/ansible/inventory'
  playbook_path: '/etc/ansible/playbooks'
  execution_timeout: 300000
  config: '/etc/ansible/ansible.cfg'
pabawi::integrations::ansible::inventory_source: 'https://github.com/example/ansible-inventory.git'
pabawi::integrations::ansible::playbook_source: 'https://github.com/example/ansible-playbooks.git'
```

**Generated .env entries:**
```
ANSIBLE_ENABLED=true
ANSIBLE_INVENTORY_PATH=/etc/ansible/inventory
ANSIBLE_PLAYBOOK_PATH=/etc/ansible/playbooks
ANSIBLE_EXECUTION_TIMEOUT=300000
ANSIBLE_CONFIG=/etc/ansible/ansible.cfg
```

### PuppetDB Integration

Manages PuppetDB connection and SSL certificates.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | Boolean | true | Whether the integration is enabled (sets PUPPETDB_ENABLED in .env) |
| `settings` | Hash | {} | Hash of configuration settings (see below) |
| `ssl_ca_source` | String | undef | URL to download CA cert from |
| `ssl_cert_source` | String | undef | URL to download client cert from |
| `ssl_key_source` | String | undef | URL to download private key from |

**Settings Hash Keys:**

| Key | Type | Description |
|-----|------|-------------|
| `server_url` | String | PuppetDB server URL (required) |
| `port` | Integer | PuppetDB server port |
| `ssl_enabled` | Boolean | Use SSL for connection |
| `ssl_ca` | String | Path to CA certificate |
| `ssl_cert` | String | Path to client certificate |
| `ssl_key` | String | Path to private key |
| `ssl_reject_unauthorized` | Boolean | Reject unauthorized certificates |

**Example:**

```yaml
# Enable PuppetDB integration
pabawi::integrations:
  - puppetdb

# Configure PuppetDB parameters
pabawi::integrations::puppetdb::settings:
  server_url: 'https://puppetdb.example.com'
  port: 8081
  ssl_enabled: true
  ssl_ca: '/etc/pabawi/ssl/puppetdb/ca.pem'
  ssl_cert: '/etc/pabawi/ssl/puppetdb/cert.pem'
  ssl_key: '/etc/pabawi/ssl/puppetdb/key.pem'
  ssl_reject_unauthorized: true
pabawi::integrations::puppetdb::ssl_ca_source: 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem'
pabawi::integrations::puppetdb::ssl_cert_source: 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem'
pabawi::integrations::puppetdb::ssl_key_source: 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem'
```

**Generated .env entries:**
```
PUPPETDB_ENABLED=true
PUPPETDB_SERVER_URL=https://puppetdb.example.com
PUPPETDB_PORT=8081
PUPPETDB_SSL_ENABLED=true
PUPPETDB_SSL_CA=/etc/pabawi/ssl/puppetdb/ca.pem
PUPPETDB_SSL_CERT=/etc/pabawi/ssl/puppetdb/cert.pem
PUPPETDB_SSL_KEY=/etc/pabawi/ssl/puppetdb/key.pem
PUPPETDB_SSL_REJECT_UNAUTHORIZED=true
```

### Puppet Server Integration

Manages Puppet Server connection with advanced circuit breaker configuration.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | Boolean | true | Whether the integration is enabled (sets PUPPETSERVER_ENABLED in .env) |
| `settings` | Hash | {} | Hash of configuration settings (see below) |
| `ssl_ca_source` | String | undef | URL to download CA cert from |
| `ssl_cert_source` | String | undef | URL to download client cert from |
| `ssl_key_source` | String | undef | URL to download private key from |

**Settings Hash Keys:**

| Key | Type | Description |
|-----|------|-------------|
| `server_url` | String | Puppet Server URL (required) |
| `port` | Integer | Puppet Server port |
| `ssl_enabled` | Boolean | Use SSL for connection |
| `ssl_ca` | String | Path to CA certificate |
| `ssl_cert` | String | Path to client certificate |
| `ssl_key` | String | Path to private key |
| `ssl_reject_unauthorized` | Boolean | Reject unauthorized certificates |
| `inactivity_threshold` | Integer | Node inactivity threshold (seconds) |
| `cache_ttl` | Integer | Cache TTL (milliseconds) |
| `circuit_breaker_threshold` | Integer | Failures before circuit opens |
| `circuit_breaker_timeout` | Integer | Circuit breaker timeout (ms) |
| `circuit_breaker_reset_timeout` | Integer | Circuit reset timeout (ms) |

**Example:**

```yaml
# Enable Puppet Server integration
pabawi::integrations:
  - puppetserver

# Configure Puppet Server parameters
pabawi::integrations::puppetserver::settings:
  server_url: 'https://puppet.example.com'
  port: 8140
  ssl_enabled: true
  ssl_ca: '/etc/pabawi/ssl/puppetserver/ca.pem'
  ssl_cert: '/etc/pabawi/ssl/puppetserver/cert.pem'
  ssl_key: '/etc/pabawi/ssl/puppetserver/key.pem'
  ssl_reject_unauthorized: true
  inactivity_threshold: 3600
  cache_ttl: 300000
  circuit_breaker_threshold: 5
  circuit_breaker_timeout: 60000
  circuit_breaker_reset_timeout: 30000
pabawi::integrations::puppetserver::ssl_ca_source: 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem'
pabawi::integrations::puppetserver::ssl_cert_source: 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem'
pabawi::integrations::puppetserver::ssl_key_source: 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem'
```

### Hiera Integration

Manages Hiera control repository and fact sources.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | Boolean | true | Whether the integration is enabled (sets HIERA_ENABLED in .env) |
| `settings` | Hash | {} | Hash of configuration settings (see below) |
| `manage_package` | Boolean | false | Install hiera package |
| `control_repo_source` | String | undef | Git URL to clone control repo from |

**Settings Hash Keys:**

| Key | Type | Description |
|-----|------|-------------|
| `control_repo_path` | String | Local path for control repo (required) |
| `config_path` | String | Hiera config file (relative to repo) |
| `environments` | Array[String] | Puppet environments to support |
| `fact_source_prefer_puppetdb` | Boolean | Prefer PuppetDB for facts |
| `fact_source_local_path` | String | Local path for fact files |

**Example:**

```yaml
# Enable Hiera integration
pabawi::integrations:
  - hiera

# Configure Hiera parameters
pabawi::integrations::hiera::manage_package: false
pabawi::integrations::hiera::settings:
  control_repo_path: '/opt/control-repo'
  config_path: 'hiera.yaml'
  environments:
    - 'production'
    - 'development'
    - 'staging'
  fact_source_prefer_puppetdb: true
pabawi::integrations::hiera::control_repo_source: 'https://github.com/example/control-repo.git'
```

**Generated .env entries:**
```
HIERA_ENABLED=true
HIERA_CONTROL_REPO_PATH=/opt/control-repo
HIERA_CONFIG_PATH=hiera.yaml
HIERA_ENVIRONMENTS=["production","development","staging"]
HIERA_FACT_SOURCE_PREFER_PUPPETDB=true
```

### SSH Integration

Manages direct SSH execution configuration.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | Boolean | true | Whether the integration is enabled (sets SSH_ENABLED in .env) |
| `settings` | Hash | {} | Hash of configuration settings (see below) |

**Settings Hash Keys:**

| Key | Type | Description |
|-----|------|-------------|
| `config_path` | String | Path to SSH config file |
| `default_user` | String | Default SSH username |
| `default_port` | Integer | Default SSH port |
| `default_key` | String | Path to default SSH private key |
| `host_key_check` | Boolean | Enable host key checking |
| `connection_timeout` | Integer | Connection timeout (seconds) |
| `command_timeout` | Integer | Command timeout (seconds) |
| `max_connections` | Integer | Maximum total connections |
| `max_connections_per_host` | Integer | Maximum connections per host |
| `idle_timeout` | Integer | Idle connection timeout (seconds) |
| `concurrency_limit` | Integer | Concurrent execution limit |

**Example:**

```yaml
pabawi::integrations:
  - ssh

pabawi::integrations::ssh::settings:
  default_user: 'automation'
  default_port: 22
  default_key: '/opt/pabawi/ssh/id_ed25519'
  host_key_check: true
  connection_timeout: 30
  command_timeout: 300
  max_connections: 50
  concurrency_limit: 10
```

**Generated .env entries:**
```
SSH_ENABLED=true
SSH_DEFAULT_USER=automation
SSH_DEFAULT_PORT=22
SSH_DEFAULT_KEY=/opt/pabawi/ssh/id_ed25519
SSH_HOST_KEY_CHECK=true
SSH_CONNECTION_TIMEOUT=30
SSH_COMMAND_TIMEOUT=300
SSH_MAX_CONNECTIONS=50
SSH_CONCURRENCY_LIMIT=10
```

### Proxmox Integration

Manages Proxmox VE connection for VM/LXC provisioning and lifecycle management.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | Boolean | true | Whether the integration is enabled (sets PROXMOX_ENABLED in .env) |
| `settings` | Hash | {} | Hash of configuration settings (see below) |
| `ssl_ca_source` | String | undef | URL to download CA cert from |
| `ssl_cert_source` | String | undef | URL to download client cert from |
| `ssl_key_source` | String | undef | URL to download private key from |

**Settings Hash Keys:**

| Key | Type | Description |
|-----|------|-------------|
| `host` | String | Proxmox host (required) |
| `port` | Integer | Proxmox API port (default 8006) |
| `token` | String | API token (recommended auth method) |
| `username` | String | Username (alternative auth) |
| `password` | String | Password (alternative auth) |
| `realm` | String | Authentication realm |
| `ssl_reject_unauthorized` | Boolean | Reject unauthorized certificates |
| `ssl_ca` | String | Path to CA certificate |
| `ssl_cert` | String | Path to client certificate |
| `ssl_key` | String | Path to private key |
| `timeout` | Integer | API timeout (milliseconds) |
| `priority` | Integer | Integration priority |

**Example:**

```yaml
pabawi::integrations:
  - proxmox

pabawi::integrations::proxmox::settings:
  host: 'proxmox.example.com'
  port: 8006
  token: 'user@pam!tokenid=token-value'
  ssl_reject_unauthorized: true
  timeout: 30000
```

**Generated .env entries:**
```
PROXMOX_ENABLED=true
PROXMOX_HOST=proxmox.example.com
PROXMOX_PORT=8006
PROXMOX_TOKEN=user@pam!tokenid=token-value
PROXMOX_SSL_REJECT_UNAUTHORIZED=true
PROXMOX_TIMEOUT=30000
```

### AWS Integration

Manages AWS EC2 integration for inventory discovery, lifecycle actions, and provisioning.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | Boolean | true | Whether the integration is enabled (sets AWS_ENABLED in .env) |
| `settings` | Hash | {} | Hash of configuration settings (see below) |

**Settings Hash Keys:**

| Key | Type | Description |
|-----|------|-------------|
| `access_key_id` | String | AWS access key ID (explicit auth) |
| `secret_access_key` | String | AWS secret access key (explicit auth) |
| `default_region` | String | Default AWS region |
| `regions` | Array[String] | Regions to query for inventory |
| `session_token` | String | AWS session token (temporary credentials) |
| `profile` | String | AWS named profile (recommended) |
| `endpoint` | String | Custom AWS endpoint URL |

**Example:**

```yaml
pabawi::integrations:
  - aws

# Using named profile (recommended)
pabawi::integrations::aws::settings:
  profile: 'pabawi-prod'
  default_region: 'us-east-1'
  regions:
    - 'us-east-1'
    - 'eu-west-1'
```

**Generated .env entries:**
```
AWS_ENABLED=true
AWS_PROFILE=pabawi-prod
AWS_DEFAULT_REGION=us-east-1
AWS_REGIONS=["us-east-1","eu-west-1"]
```

## Examples

### Complete Multi-Integration Setup

```yaml
# Hiera data (data/common.yaml or node-specific)
pabawi::proxy_manage: true
pabawi::proxy_class: 'pabawi::proxy::nginx'
pabawi::install_manage: true
pabawi::install_class: 'pabawi::install::npm'

# Enable integrations via array
pabawi::integrations:
  - bolt
  - ansible
  - puppetdb
  - puppetserver
  - hiera
  - ssh
  - proxmox
  - aws

# Bolt integration configuration
pabawi::integrations::bolt::manage_package: true
pabawi::integrations::bolt::settings:
  project_path: '/opt/pabawi/bolt-project'
  execution_timeout: 300000
pabawi::integrations::bolt::project_path_source: 'https://github.com/myorg/bolt-project.git'

# Ansible integration configuration
pabawi::integrations::ansible::manage_package: true
pabawi::integrations::ansible::settings:
  inventory_path: '/opt/pabawi/ansible/inventory'
  playbook_path: '/opt/pabawi/ansible/playbooks'
  execution_timeout: 300000
pabawi::integrations::ansible::inventory_source: 'https://github.com/myorg/ansible-inventory.git'
pabawi::integrations::ansible::playbook_source: 'https://github.com/myorg/ansible-playbooks.git'

# PuppetDB integration configuration
pabawi::integrations::puppetdb::settings:
  server_url: 'https://puppetdb.myorg.com'
  port: 8081
  ssl_enabled: true
  ssl_reject_unauthorized: true
pabawi::integrations::puppetdb::ssl_ca_source: 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem'
pabawi::integrations::puppetdb::ssl_cert_source: 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem'
pabawi::integrations::puppetdb::ssl_key_source: 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem'

# Puppet Server integration configuration
pabawi::integrations::puppetserver::settings:
  server_url: 'https://puppet.myorg.com'
  port: 8140
  ssl_enabled: true
  ssl_reject_unauthorized: true
  inactivity_threshold: 3600
  cache_ttl: 300000
pabawi::integrations::puppetserver::ssl_ca_source: 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem'
pabawi::integrations::puppetserver::ssl_cert_source: 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem'
pabawi::integrations::puppetserver::ssl_key_source: 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem'

# Hiera integration configuration
pabawi::integrations::hiera::settings:
  control_repo_path: '/opt/pabawi/control-repo'
  config_path: 'hiera.yaml'
  environments:
    - 'production'
    - 'development'
  fact_source_prefer_puppetdb: true
pabawi::integrations::hiera::control_repo_source: 'https://github.com/myorg/control-repo.git'

# SSH integration configuration
pabawi::integrations::ssh::settings:
  default_user: 'automation'
  default_port: 22
  default_key: '/opt/pabawi/ssh/id_ed25519'
  host_key_check: true
  connection_timeout: 30
  max_connections: 50
  concurrency_limit: 10

# Proxmox integration configuration
pabawi::integrations::proxmox::settings:
  host: 'proxmox.myorg.com'
  port: 8006
  token: 'automation@pve!pabawi=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'
  ssl_reject_unauthorized: true
  timeout: 30000

# AWS integration configuration
pabawi::integrations::aws::settings:
  profile: 'pabawi-prod'
  default_region: 'us-east-1'
  regions:
    - 'us-east-1'
    - 'eu-west-1'

# Nginx proxy settings
pabawi::proxy::nginx::ssl_enable: true
pabawi::proxy::nginx::ssl_self_signed: false
pabawi::proxy::nginx::ssl_cert_source: 'puppet:///modules/site/ssl/pabawi.crt'
pabawi::proxy::nginx::ssl_key_source: 'puppet:///modules/site/ssl/pabawi.key'
pabawi::proxy::nginx::listen_port: 443
pabawi::proxy::nginx::backend_port: 3000

# NPM installation settings
pabawi::install::npm::install_dir: '/opt/pabawi/app'
pabawi::install::npm::repo_url: 'https://github.com/example42/pabawi.git'
pabawi::install::npm::version: 'v1.0.0'
pabawi::install::npm::auth_enabled: true
pabawi::install::npm::jwt_secret: 'your-secure-secret-here'
```

### Docker Installation with Custom SSL

```yaml
pabawi::install_class: 'pabawi::install::docker'

# Enable PuppetDB integration
pabawi::integrations:
  - puppetdb

# Configure PuppetDB
pabawi::integrations::puppetdb::settings:
  server_url: 'https://puppetdb.example.com'
  ssl_enabled: true
  ssl_ca: '/etc/pabawi/ssl/puppetdb/ca.pem'
  ssl_cert: '/etc/pabawi/ssl/puppetdb/cert.pem'
  ssl_key: '/etc/pabawi/ssl/puppetdb/key.pem'
pabawi::integrations::puppetdb::ssl_ca_source: 'https://certserver.example.com/ca.pem'
pabawi::integrations::puppetdb::ssl_cert_source: 'https://certserver.example.com/pabawi.pem'
pabawi::integrations::puppetdb::ssl_key_source: 'https://certserver.example.com/pabawi-key.pem'

# Docker settings
pabawi::install::docker::image: 'example42/pabawi:latest'
pabawi::install::docker::volumes:
  - '/data/pabawi:/app/data'
  - '/etc/pabawi/ssl:/app/ssl:ro'
```

### Minimal Setup (Bolt Only)

```yaml
# Enable only Bolt integration
pabawi::integrations:
  - bolt

# Configure Bolt
pabawi::integrations::bolt::settings:
  project_path: '/opt/pabawi/bolt-project'
```

### Complete Hiera Configuration Examples

For full Hiera configuration examples covering all integrations (Bolt, PuppetDB, Puppet Server, Hiera, Ansible, SSH, Proxmox, AWS), see the `examples/` directory:

- `examples/hiera_full_integrations.yaml` — Complete Hiera data with every integration
- `examples/full_integrations.pp` — Puppet-centric setup (Bolt, PuppetDB, Puppet Server, Hiera)
- `examples/ssh_ansible_proxmox.pp` — Agentless setup (SSH, Ansible, Proxmox)
- `examples/docker_custom_ssl.pp` — Docker installation with custom SSL
- `examples/basic_nginx_npm.pp` — Minimal defaults
- `examples/minimal_no_proxy.pp` — No proxy, npm only

## Reference

See [REFERENCE.md](REFERENCE.md) for detailed parameter documentation generated from Puppet Strings.

## Limitations

- Docker installation method requires Docker to be available
- SSL certificate management requires proper file permissions
- Git repository cloning requires git to be installed
- HTTPS certificate downloads require curl to be available

## Development

Contributions are welcome! Please submit pull requests or issues on GitHub.

### Testing

```bash
bundle install
bundle exec rake test
```

### Module Structure

```
puppet-pabawi/
├── manifests/
│   ├── init.pp                      # Main class
│   ├── install/
│   │   ├── npm.pp                   # NPM installation
│   │   └── docker.pp                # Docker installation
│   ├── proxy/
│   │   └── nginx.pp                 # Nginx proxy
│   └── integrations/
│       ├── bolt.pp                  # Bolt integration
│       ├── ansible.pp               # Ansible integration
│       ├── puppetdb.pp              # PuppetDB integration
│       ├── puppetserver.pp          # Puppet Server integration
│       ├── hiera.pp                 # Hiera integration
│       ├── ssh.pp                   # SSH integration
│       ├── proxmox.pp              # Proxmox integration
│       └── aws.pp                   # AWS integration
├── data/
│   └── common.yaml                  # Default Hiera data
├── examples/                        # Usage examples
└── README.md                        # This file
```
