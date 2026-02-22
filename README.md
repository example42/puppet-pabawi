# Puppet module to install pabawi

## Usage

    include pabawi

## Configuration

Sample Hiera settings:

    ---
    pabawi::proxy_manage: true # By default we install a nginx as proxy
    pabawi::proxy_class: pabawi::proxy::nginx # Default
    pabawi::proxy::nginx::ssl_enable: # true. default ssl self signed, allow customisation

    pabawi::install_manage: true # By default we manage pabawi installation
    pabawi::install_class: pabawi::install::npm # By default we install from source using npm. Provide also pabawi::install::docker

    pabawi::bolt_enable: true
    pabawi::bolt_project_path:  ...

    pabawi::puppetdb_enable: true
    pabawi::puppetdb_server_url: ...

    # provide similar settings for each integration
