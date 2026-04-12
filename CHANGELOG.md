# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-04-12

### Added

- **Proxmox integration** (`pabawi::integrations::proxmox`) — Proxmox VE
  support for VM/LXC provisioning and lifecycle management. Token and
  username/password authentication, SSL certificate deployment via
  `ssl_ca_source`, `ssl_cert_source`, `ssl_key_source` parameters.
- **AWS integration** (`pabawi::integrations::aws`) — AWS EC2 inventory
  discovery, lifecycle actions (start/stop/reboot/terminate), and instance
  provisioning. Supports explicit access keys, named profiles, and the
  default AWS credential chain.
- **SSH integration** added to the `integrations` enum — the manifest existed
  since 0.2.0 but was not accepted by the `Enum` type on `pabawi::integrations`.
- New example `examples/ssh_ansible_proxmox.pp` — agentless infrastructure
  setup with SSH, Ansible, and Proxmox.
- New example `examples/hiera_full_integrations.yaml` — complete Hiera data
  covering all eight integrations.
- SSH, Proxmox, and AWS integration reference sections in README with
  parameter tables, Hiera examples, and generated `.env` samples.

### Changed

- **Docker installation refactored to systemd** — `pabawi::install::docker`
  now runs the container as a native systemd service via `docker run`,
  removing the dependency on the `puppetlabs/docker` module. New parameters:
  `manage_docker`, `docker_package`, `bind_address`, `database_host_dir`,
  `container_uid`, `container_gid`, `command_whitelist`,
  `command_whitelist_allow_all`, `docker_extra_args`.
- **NPM installation** — added `bind_address` parameter that defaults to
  `127.0.0.1` when `pabawi::proxy_manage` is true, `0.0.0.0` otherwise.
- `pabawi::integrations` enum expanded from
  `['puppetdb','puppetserver','hiera','bolt','ansible']` to
  `['puppetdb','puppetserver','hiera','bolt','ansible','ssh','proxmox','aws']`.
- Integration SSL certificate deployment (PuppetDB, Puppet Server) refactored
  to use `ensure_resource` for directory management, avoiding duplicate
  resource declarations when multiple integrations share parent directories.
- `examples/full_integrations.pp` slimmed to a minimal Puppet-centric setup
  (Bolt, PuppetDB, Puppet Server, Hiera). Full verbose examples moved to
  `hiera_full_integrations.yaml`.
- `examples/docker_custom_ssl.pp` updated to use `v1.0.0` image and proper
  `auth_enabled`/`jwt_secret` parameters.
- README rewritten: added SSH/Proxmox/AWS integration reference, updated all
  inline examples to use current parameter names and default paths, replaced
  large inline Hiera examples with pointers to `examples/` directory.
- Hiera defaults (`data/common.yaml`) updated with commented examples for all
  eight integrations.
- Design document updated with Proxmox (Component 8), SSH (Component 7), and
  AWS (Component 9) sections; architecture diagram expanded.
- Spec tests updated to cover `ssh`, `proxmox`, and `aws` integration values.

### Fixed

- `.env` concat fragment ordering now correctly sequences all integrations:
  Bolt (20), PuppetDB (21), Puppet Server (22), Hiera (23), Ansible (24),
  SSH (25), Proxmox (26), AWS (27).
- Fixed service exec path in NPM installation (contributed by @tam116 in #9).

### Removed

- `puppetlabs/docker` is no longer a required dependency — Docker installation
  uses direct `docker run` via systemd instead.

## [0.2.0] - 2025-02-15

### Changed

- Refactored all integrations to use a `settings` hash parameter instead of
  individual parameters, providing a uniform interface across integrations.
- Updated integration configuration examples and documentation to use the new
  settings hash pattern.
- Updated module dependencies version ranges.

## [0.1.1] - 2025-01-20

### Changed

- Updated supported OS matrix (Ubuntu 24.04, Debian 13, RHEL 8/9/10).
- Upgraded `puppetlabs_spec_helper` dependency.

### Fixed

- Various Gemfile dependency fixes for CI compatibility.

## [0.1.0] - 2025-01-10

### Added

- Initial release.
- Core module with `pabawi::init` entry point, proxy management, and
  installation management.
- NPM installation method (`pabawi::install::npm`).
- Docker installation method (`pabawi::install::docker`).
- Nginx reverse proxy with SSL (`pabawi::proxy::nginx`).
- Bolt integration (`pabawi::integrations::bolt`).
- PuppetDB integration (`pabawi::integrations::puppetdb`).
- Puppet Server integration (`pabawi::integrations::puppetserver`).
- Hiera integration (`pabawi::integrations::hiera`).
- Ansible integration (`pabawi::integrations::ansible`).
- SSH integration (`pabawi::integrations::ssh`).
- Hiera-driven configuration with `data/common.yaml` defaults.
- `Pabawi::Config`, `Pabawi::SSL::Config`, `Pabawi::Integration::Config` types.
- `pabawi::validate_configuration` function.
- rspec-puppet spec tests.
- GitHub Actions CI/CD workflows.
- Usage examples in `examples/`.

[1.0.0]: https://github.com/example42/puppet-pabawi/compare/0.2.0...1.0.0
[0.2.0]: https://github.com/example42/puppet-pabawi/compare/0.1.1...0.2.0
[0.1.1]: https://github.com/example42/puppet-pabawi/compare/0.1.0...0.1.1
[0.1.0]: https://github.com/example42/puppet-pabawi/releases/tag/0.1.0
