# Implementation Plan: Puppet Pabawi Module

## Overview

This implementation plan breaks down the Puppet Pabawi module into discrete coding tasks. The module provides flexible installation and configuration of the Pabawi application with support for multiple installation methods (npm, docker), proxy configurations (nginx with SSL), and various integrations (Bolt, PuppetDB). Each task builds incrementally, ensuring components are tested and integrated as we progress.

## Tasks

- [x] 1. Set up module structure and core types
  - Create standard Puppet module directory structure (manifests/, types/, functions/, spec/)
  - Define custom types for Pabawi::Config, Pabawi::SSL::Config, and Pabawi::Integration::Config
  - Set up metadata.json with dependencies (stdlib, nginx, docker, vcsrepo, concat)
  - Create basic spec_helper.rb for rspec-puppet testing
  - _Requirements: Module architecture, type system_

- [ ]* 1.1 Write unit tests for custom types
  - Test type validation rules for all custom types
  - Test parameter constraints and default values
  - _Requirements: Type validation_

- [ ] 2. Implement main module class (pabawi::init)
  - [x] 2.1 Create pabawi::init class with parameter definitions
    - Define all parameters with types and defaults (proxy_manage, proxy_class, install_manage, install_class, bolt_enable, puppetdb_enable, integrations)
    - Implement parameter validation logic
    - _Requirements: Main module interface, configuration management_
  
  - [x] 2.2 Implement conditional proxy inclusion logic
    - Add conditional logic to include proxy class when proxy_manage is true
    - Implement dynamic class inclusion using $proxy_class parameter
    - Add validation to ensure proxy_class is a valid class name
    - _Requirements: Proxy management, component independence_
  
  - [x] 2.3 Implement conditional installation inclusion logic
    - Add conditional logic to include installation class when install_manage is true
    - Implement dynamic class inclusion using $install_class parameter
    - Ensure installation happens after proxy configuration (resource ordering)
    - _Requirements: Installation management, dependency ordering_
  
  - [x] 2.4 Implement integration processing logic
    - Process bolt_enable and puppetdb_enable flags
    - Iterate through integrations hash and include enabled integration classes
    - Add warning logging for missing integration classes
    - _Requirements: Integration framework, extensibility_
  
  - [ ]* 2.5 Write unit tests for pabawi::init
    - Test default parameters produce valid catalog
    - Test conditional inclusion of proxy and install classes
    - Test integration processing logic
    - Test resource ordering (proxy before install)
    - _Requirements: Main module correctness_

- [x] 3. Checkpoint - Verify core module structure
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 4. Implement nginx proxy class (pabawi::proxy::nginx)
  - [~] 4.1 Create pabawi::proxy::nginx class with parameters
    - Define SSL-related parameters (ssl_enable, ssl_self_signed, ssl_cert_source, ssl_key_source, ssl_cert_path, ssl_key_path)
    - Define proxy parameters (listen_port, backend_port, server_name)
    - _Requirements: Proxy configuration interface_
  
  - [~] 4.2 Implement nginx package and service management
    - Ensure nginx package is installed
    - Manage nginx service state (running, enabled)
    - _Requirements: Proxy service management_
  
  - [~] 4.3 Implement SSL certificate management
    - Create SSL directory with proper permissions
    - Implement conditional logic for self-signed vs custom certificates
    - For self-signed: use exec resource with openssl to generate certificates
    - For custom: deploy certificates from cert_source and key_source
    - Set proper file permissions (0644 for cert, 0600 for key)
    - _Requirements: SSL certificate handling, security_
  
  - [~] 4.4 Create nginx virtual host configuration
    - Use concat or file resource to create nginx site configuration
    - Configure SSL settings when ssl_enable is true
    - Configure reverse proxy rules to backend_port
    - Add proxy headers for proper request forwarding
    - _Requirements: Reverse proxy configuration_
  
  - [~] 4.5 Wire nginx configuration to service restart
    - Ensure nginx service restarts when configuration changes
    - Ensure certificates are deployed before nginx starts
    - _Requirements: Service dependency management_
  
  - [ ]* 4.6 Write unit tests for pabawi::proxy::nginx
    - Test SSL certificate generation logic
    - Test custom certificate deployment
    - Test nginx configuration file creation
    - Test service restart triggers
    - _Requirements: Proxy correctness_

- [ ] 5. Implement npm installation class (pabawi::install::npm)
  - [~] 5.1 Create pabawi::install::npm class with parameters
    - Define parameters (install_dir, repo_url, version, user, group, npm_config)
    - _Requirements: NPM installation interface_
  
  - [~] 5.2 Implement user and group management
    - Create application user and group using user and group resources
    - Set appropriate user properties (home directory, shell)
    - _Requirements: Security, user isolation_
  
  - [~] 5.3 Implement directory structure setup
    - Create install_dir with proper ownership and permissions
    - Ensure parent directories exist
    - _Requirements: File system setup_
  
  - [~] 5.4 Implement Node.js and npm installation
    - Ensure nodejs and npm packages are installed
    - Handle different package names across OS distributions
    - _Requirements: Dependency management_
  
  - [~] 5.5 Implement git repository management
    - Use vcsrepo resource to clone/update repository
    - Configure repository URL, version/branch, and user
    - _Requirements: Source code management_
  
  - [~] 5.6 Implement npm dependency installation
    - Use exec resource to run npm install
    - Set proper working directory and user
    - Add unless condition to avoid unnecessary runs
    - Apply npm_config parameters
    - _Requirements: Dependency installation_
  
  - [~] 5.7 Implement application build process
    - Use exec resource to run npm build
    - Ensure build runs after npm install
    - _Requirements: Application build_
  
  - [~] 5.8 Implement systemd service configuration
    - Create systemd service file for pabawi application
    - Configure ExecStart, User, WorkingDirectory, and restart policies
    - _Requirements: Service management_
  
  - [~] 5.9 Manage pabawi service state
    - Ensure pabawi service is running and enabled
    - Ensure service starts after installation completes
    - _Requirements: Service lifecycle_
  
  - [ ]* 5.10 Write unit tests for pabawi::install::npm
    - Test user and group creation
    - Test directory creation with proper permissions
    - Test package installation
    - Test vcsrepo configuration
    - Test exec resources for npm commands
    - Test systemd service creation
    - _Requirements: NPM installation correctness_

- [x] 6. Checkpoint - Verify npm installation path
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 7. Implement docker installation class (pabawi::install::docker)
  - [~] 7.1 Create pabawi::install::docker class with parameters
    - Define parameters (image, container_name, environment, volumes, ports, auto_restart)
    - _Requirements: Docker installation interface_
  
  - [~] 7.2 Ensure Docker is installed and running
    - Use puppetlabs/docker module to manage Docker installation
    - Ensure docker service is running
    - _Requirements: Docker dependency_
  
  - [~] 7.3 Implement Docker image management
    - Use docker::image resource to pull specified image
    - _Requirements: Image management_
  
  - [~] 7.4 Implement Docker container configuration
    - Use docker::run resource to create and manage container
    - Configure container name, image, environment variables, volumes, and port mappings
    - Set restart policy based on auto_restart parameter
    - _Requirements: Container lifecycle_
  
  - [ ]* 7.5 Write unit tests for pabawi::install::docker
    - Test Docker installation
    - Test image pull configuration
    - Test container creation with all parameters
    - Test restart policy configuration
    - _Requirements: Docker installation correctness_

- [ ] 8. Implement Bolt integration class (pabawi::integrations::bolt)
  - [~] 8.1 Create pabawi::integrations::bolt class with parameters
    - Define parameters (project_path, bolt_config_path, bolt_settings)
    - Add parameter validation for project_path
    - _Requirements: Bolt integration interface_
  
  - [~] 8.2 Validate Bolt project path exists
    - Add validation to ensure project_path directory exists
    - Fail with descriptive error if path is invalid
    - _Requirements: Integration validation_
  
  - [~] 8.3 Create Bolt integration configuration
    - Create configuration file for Pabawi-Bolt integration
    - Use file or concat resource to generate config
    - Apply bolt_settings parameters
    - _Requirements: Bolt configuration_
  
  - [ ]* 8.4 Write unit tests for pabawi::integrations::bolt
    - Test parameter validation
    - Test configuration file creation
    - Test error handling for invalid paths
    - _Requirements: Bolt integration correctness_

- [ ] 9. Implement PuppetDB integration class (pabawi::integrations::puppetdb)
  - [~] 9.1 Create pabawi::integrations::puppetdb class with parameters
    - Define parameters (server_url, ssl_cert, ssl_key, ssl_ca, timeout)
    - Add URL validation for server_url
    - _Requirements: PuppetDB integration interface_
  
  - [~] 9.2 Implement SSL certificate deployment for PuppetDB
    - Deploy SSL certificates if provided
    - Set proper file permissions for certificates
    - _Requirements: Secure PuppetDB connection_
  
  - [~] 9.3 Create PuppetDB integration configuration
    - Create configuration file with server URL, SSL settings, and timeout
    - Use file or concat resource to generate config
    - _Requirements: PuppetDB configuration_
  
  - [ ]* 9.4 Write unit tests for pabawi::integrations::puppetdb
    - Test parameter validation
    - Test SSL certificate deployment
    - Test configuration file creation
    - _Requirements: PuppetDB integration correctness_

- [ ] 10. Implement helper functions
  - [~] 10.1 Create pabawi::validate_configuration function
    - Implement validation logic for Pabawi::Config type
    - Return boolean indicating validity
    - _Requirements: Configuration validation_
  
  - [ ]* 10.2 Write unit tests for helper functions
    - Test validation with valid configurations
    - Test validation with invalid configurations
    - _Requirements: Function correctness_

- [~] 11. Create Hiera data examples
  - Create data/common.yaml with sensible defaults
  - Create examples/ directory with sample Hiera configurations
  - Document all available parameters
  - _Requirements: User documentation, ease of use_

- [ ] 12. Integration and wiring verification
  - [~] 12.1 Create example manifests for common scenarios
    - Basic installation with nginx proxy
    - Docker installation with custom SSL
    - Full integration setup
    - Minimal installation without proxy
    - _Requirements: Usage examples_
  
  - [~] 12.2 Verify resource ordering across all components
    - Ensure proxy resources come before installation resources
    - Ensure installation completes before service starts
    - Ensure certificates are deployed before nginx starts
    - _Requirements: Dependency ordering correctness_
  
  - [ ]* 12.3 Write integration tests using rspec-puppet
    - Test complete module application with default parameters
    - Test all installation method combinations
    - Test all integration combinations
    - Test resource ordering in compiled catalogs
    - _Requirements: End-to-end correctness_

- [x] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- The module uses Puppet DSL throughout
- All classes follow Puppet best practices with Hiera-driven configuration
- Resource ordering is critical: proxy → installation → service startup
- SSL certificate management requires careful permission handling (0600 for keys)
- Integration classes are designed to be independently enabled/disabled
- The module supports extensibility through the integrations hash parameter
