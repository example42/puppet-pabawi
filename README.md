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
- [Examples](#examples)
- [Reference](#reference)
- [Limitations](#limitations)
- [Development](#development)

## Description

Pabawi is a unified web interface for interacting with various Puppet ecosystem tools including Bolt, PuppetDB, Puppet Server, Hiera, and Ansible. This Puppet module manages the installation and configuration of Pabawi and its integrations.

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

# Configure each integration via class parameters
pabawi::integrations::bolt::project_path: '/opt/bolt-project'
pabawi::integrations::bolt::command_whitelist:
  - 'plan run'
  - 'task run'

pabawi::integrations::puppetdb::server_url: 'https://puppetdb.example.com:8081'
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
pabawi::integrations::bolt::project_path: '/opt/bolt-project'
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
pabawi::integrations::bolt::project_path: '/opt/bolt-project'
pabawi::integrations::bolt::command_whitelist:
  - 'plan run'
  - 'task run'
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
BOLT_PROJECT_PATH=/opt/bolt-project
BOLT_COMMAND_WHITELIST=["ls","pwd"]
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
```

### Content Sources

The module supports cloning git repositories and downloading files from various sources:

#### Git Repository Sources

For directory-based content (Bolt projects, Ansible inventories, Hiera control repos):

```yaml
pabawi::integrations:
  - bolt

pabawi::integrations::bolt::project_path: '/opt/bolt-project'
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
pabawi::integrations::bolt::project_path: '/opt/bolt-project'
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
| `manage_package` | Boolean | false | Install puppet-bolt package |
| `project_path` | Absolute path | - | Local path for Bolt project (required) |
| `project_path_source` | String | undef | Git URL to clone project from |
| `command_whitelist` | Array[String] | [] | Allowed commands (JSON array in .env) |
| `command_whitelist_allow_all` | Boolean | false | Allow all commands (security risk) |
| `execution_timeout` | Integer | 300000 | Command timeout in milliseconds |

**Example:**

```yaml
# Enable Bolt integration
pabawi::integrations:
  - bolt

# Configure Bolt parameters
pabawi::integrations::bolt::manage_package: true
pabawi::integrations::bolt::project_path: '/opt/bolt-project'
pabawi::integrations::bolt::project_path_source: 'https://github.com/example/bolt-project.git'
pabawi::integrations::bolt::command_whitelist:
  - 'plan run'
  - 'task run'
  - 'command run'
pabawi::integrations::bolt::command_whitelist_allow_all: false
pabawi::integrations::bolt::execution_timeout: 300000
```

**Generated .env entries:**
```
BOLT_ENABLED=true
BOLT_PROJECT_PATH=/opt/bolt-project
BOLT_COMMAND_WHITELIST=["plan run","task run","command run"]
BOLT_COMMAND_WHITELIST_ALLOW_ALL=false
BOLT_EXECUTION_TIMEOUT=300000
```

### Ansible Integration

Manages Ansible inventory and playbook configuration.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | Boolean | true | Whether the integration is enabled (sets ANSIBLE_ENABLED in .env) |
| `manage_package` | Boolean | false | Install ansible package |
| `inventory_path` | Absolute path | - | Local path for inventory (required) |
| `inventory_source` | String | undef | Git URL to clone inventory from |
| `playbook_path` | Absolute path | undef | Local path for playbooks |
| `playbook_source` | String | undef | Git URL to clone playbooks from |
| `execution_timeout` | Integer | 300000 | Command timeout in milliseconds |
| `config` | Absolute path | undef | Path to ansible.cfg file |

**Example:**

```yaml
# Enable Ansible integration
pabawi::integrations:
  - ansible

# Configure Ansible parameters
pabawi::integrations::ansible::manage_package: true
pabawi::integrations::ansible::inventory_path: '/etc/ansible/inventory'
pabawi::integrations::ansible::inventory_source: 'https://github.com/example/ansible-inventory.git'
pabawi::integrations::ansible::playbook_path: '/etc/ansible/playbooks'
pabawi::integrations::ansible::playbook_source: 'https://github.com/example/ansible-playbooks.git'
pabawi::integrations::ansible::execution_timeout: 300000
pabawi::integrations::ansible::config: '/etc/ansible/ansible.cfg'
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
| `server_url` | String | - | PuppetDB server URL (required) |
| `port` | Integer | 8081 | PuppetDB server port |
| `ssl_enabled` | Boolean | true | Use SSL for connection |
| `ssl_ca` | String | undef | Path to CA certificate |
| `ssl_cert` | String | undef | Path to client certificate |
| `ssl_key` | String | undef | Path to private key |
| `ssl_ca_source` | String | undef | URL to download CA cert from |
| `ssl_cert_source` | String | undef | URL to download client cert from |
| `ssl_key_source` | String | undef | URL to download private key from |
| `ssl_reject_unauthorized` | Boolean | true | Reject unauthorized certificates |

**Example:**

```yaml
# Enable PuppetDB integration
pabawi::integrations:
  - puppetdb

# Configure PuppetDB parameters
pabawi::integrations::puppetdb::server_url: 'https://puppetdb.example.com'
pabawi::integrations::puppetdb::port: 8081
pabawi::integrations::puppetdb::ssl_enabled: true
pabawi::integrations::puppetdb::ssl_ca: '/etc/puppetlabs/puppet/ssl/certs/ca.pem'
pabawi::integrations::puppetdb::ssl_cert: '/etc/puppetlabs/puppet/ssl/certs/agent.pem'
pabawi::integrations::puppetdb::ssl_key: '/etc/puppetlabs/puppet/ssl/private_keys/agent.pem'
pabawi::integrations::puppetdb::ssl_reject_unauthorized: true
```

**With certificate sources:**

```yaml
pabawi::integrations:
  - puppetdb

pabawi::integrations::puppetdb::server_url: 'https://puppetdb.example.com'
pabawi::integrations::puppetdb::port: 8081
pabawi::integrations::puppetdb::ssl_enabled: true
pabawi::integrations::puppetdb::ssl_ca_source: 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem'
pabawi::integrations::puppetdb::ssl_cert_source: 'https://certserver.example.com/certs/pabawi.pem'
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
| `server_url` | String | - | Puppet Server URL (required) |
| `port` | Integer | 8140 | Puppet Server port |
| `ssl_enabled` | Boolean | true | Use SSL for connection |
| `ssl_ca` | String | undef | Path to CA certificate |
| `ssl_cert` | String | undef | Path to client certificate |
| `ssl_key` | String | undef | Path to private key |
| `ssl_ca_source` | String | undef | URL to download CA cert from |
| `ssl_cert_source` | String | undef | URL to download client cert from |
| `ssl_key_source` | String | undef | URL to download private key from |
| `ssl_reject_unauthorized` | Boolean | true | Reject unauthorized certificates |
| `inactivity_threshold` | Integer | 3600 | Node inactivity threshold (seconds) |
| `cache_ttl` | Integer | 300000 | Cache TTL (milliseconds) |
| `circuit_breaker_threshold` | Integer | 5 | Failures before circuit opens |
| `circuit_breaker_timeout` | Integer | 60000 | Circuit breaker timeout (ms) |
| `circuit_breaker_reset_timeout` | Integer | 30000 | Circuit reset timeout (ms) |

**Example:**

```yaml
# Enable Puppet Server integration
pabawi::integrations:
  - puppetserver

# Configure Puppet Server parameters
pabawi::integrations::puppetserver::server_url: 'https://puppet.example.com'
pabawi::integrations::puppetserver::port: 8140
pabawi::integrations::puppetserver::ssl_enabled: true
pabawi::integrations::puppetserver::ssl_ca: '/etc/puppetlabs/puppet/ssl/certs/ca.pem'
pabawi::integrations::puppetserver::ssl_cert: '/etc/puppetlabs/puppet/ssl/certs/agent.pem'
pabawi::integrations::puppetserver::ssl_key: '/etc/puppetlabs/puppet/ssl/private_keys/agent.pem'
pabawi::integrations::puppetserver::ssl_reject_unauthorized: true
pabawi::integrations::puppetserver::inactivity_threshold: 3600
pabawi::integrations::puppetserver::cache_ttl: 300000
pabawi::integrations::puppetserver::circuit_breaker_threshold: 5
pabawi::integrations::puppetserver::circuit_breaker_timeout: 60000
pabawi::integrations::puppetserver::circuit_breaker_reset_timeout: 30000
```

### Hiera Integration

Manages Hiera control repository and fact sources.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | Boolean | true | Whether the integration is enabled (sets HIERA_ENABLED in .env) |
| `manage_package` | Boolean | false | Install hiera package |
| `control_repo_path` | Absolute path | - | Local path for control repo (required) |
| `control_repo_source` | String | undef | Git URL to clone control repo from |
| `config_path` | String | 'hiera_pabawi.yaml' | Hiera config file (relative to repo) |
| `environments` | Array[String] | ['production'] | Puppet environments to support |
| `fact_source_prefer_puppetdb` | Boolean | true | Prefer PuppetDB for facts |
| `fact_source_local_path` | Absolute path | undef | Local path for fact files |

**Example:**

```yaml
# Enable Hiera integration
pabawi::integrations:
  - hiera

# Configure Hiera parameters
pabawi::integrations::hiera::manage_package: false
pabawi::integrations::hiera::control_repo_path: '/opt/control-repo'
pabawi::integrations::hiera::control_repo_source: 'https://github.com/example/control-repo.git'
pabawi::integrations::hiera::config_path: 'hiera.yaml'
pabawi::integrations::hiera::environments:
  - 'production'
  - 'development'
  - 'staging'
pabawi::integrations::hiera::fact_source_prefer_puppetdb: true
```

**Generated .env entries:**
```
HIERA_ENABLED=true
HIERA_CONTROL_REPO_PATH=/opt/control-repo
HIERA_CONFIG_PATH=hiera.yaml
HIERA_ENVIRONMENTS=["production","development","staging"]
HIERA_FACT_SOURCE_PREFER_PUPPETDB=true
HIERA_FACT_SOURCE_LOCAL_PATH=
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

# Bolt integration configuration
pabawi::integrations::bolt::manage_package: true
pabawi::integrations::bolt::project_path: '/opt/bolt-project'
pabawi::integrations::bolt::project_path_source: 'https://github.com/myorg/bolt-project.git'
pabawi::integrations::bolt::command_whitelist:
  - 'plan run'
  - 'task run'
pabawi::integrations::bolt::command_whitelist_allow_all: false
pabawi::integrations::bolt::execution_timeout: 300000

# Ansible integration configuration
pabawi::integrations::ansible::manage_package: true
pabawi::integrations::ansible::inventory_path: '/etc/ansible/inventory'
pabawi::integrations::ansible::inventory_source: 'https://github.com/myorg/ansible-inventory.git'
pabawi::integrations::ansible::playbook_path: '/etc/ansible/playbooks'
pabawi::integrations::ansible::playbook_source: 'https://github.com/myorg/ansible-playbooks.git'
pabawi::integrations::ansible::execution_timeout: 300000

# PuppetDB integration configuration
pabawi::integrations::puppetdb::server_url: 'https://puppetdb.myorg.com'
pabawi::integrations::puppetdb::port: 8081
pabawi::integrations::puppetdb::ssl_enabled: true
pabawi::integrations::puppetdb::ssl_ca_source: 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem'
pabawi::integrations::puppetdb::ssl_cert_source: 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem'
pabawi::integrations::puppetdb::ssl_key_source: 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem'
pabawi::integrations::puppetdb::ssl_reject_unauthorized: true

# Puppet Server integration configuration
pabawi::integrations::puppetserver::server_url: 'https://puppet.myorg.com'
pabawi::integrations::puppetserver::port: 8140
pabawi::integrations::puppetserver::ssl_enabled: true
pabawi::integrations::puppetserver::ssl_ca_source: 'file:///etc/puppetlabs/puppet/ssl/certs/ca.pem'
pabawi::integrations::puppetserver::ssl_cert_source: 'file:///etc/puppetlabs/puppet/ssl/certs/agent.pem'
pabawi::integrations::puppetserver::ssl_key_source: 'file:///etc/puppetlabs/puppet/ssl/private_keys/agent.pem'
pabawi::integrations::puppetserver::ssl_reject_unauthorized: true
pabawi::integrations::puppetserver::inactivity_threshold: 3600
pabawi::integrations::puppetserver::cache_ttl: 300000

# Hiera integration configuration
pabawi::integrations::hiera::manage_package: false
pabawi::integrations::hiera::control_repo_path: '/opt/control-repo'
pabawi::integrations::hiera::control_repo_source: 'https://github.com/myorg/control-repo.git'
pabawi::integrations::hiera::config_path: 'hiera.yaml'
pabawi::integrations::hiera::environments:
  - 'production'
  - 'development'
pabawi::integrations::hiera::fact_source_prefer_puppetdb: true

# Nginx proxy settings
pabawi::proxy::nginx::ssl_enable: true
pabawi::proxy::nginx::ssl_self_signed: false
pabawi::proxy::nginx::ssl_cert: '/etc/ssl/certs/pabawi.crt'
pabawi::proxy::nginx::ssl_key: '/etc/ssl/private/pabawi.key'
pabawi::proxy::nginx::listen_port: 443
pabawi::proxy::nginx::backend_port: 3000

# NPM installation settings
pabawi::install::npm::install_dir: '/opt/pabawi'
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
pabawi::integrations::puppetdb::server_url: 'https://puppetdb.example.com'
pabawi::integrations::puppetdb::ssl_enabled: true
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
pabawi::integrations::bolt::project_path: '/opt/bolt-project'
pabawi::integrations::bolt::command_whitelist:
  - 'plan run'
```

## Reference

See [REFERENCE.md](REFERENCE.md) for detailed parameter documentation generated from Puppet Strings.

## Limitations

- Currently tested on RedHat/CentOS 7+ and Ubuntu 18.04+
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
│       └── hiera.pp                 # Hiera integration
├── data/
│   └── common.yaml                  # Default Hiera data
├── examples/                        # Usage examples
└── README.md                        # This file
```
