# Example: Docker installation with custom SSL certificates
#
# This example shows how to use Docker for installation with
# custom SSL certificates for the nginx proxy.

class { 'pabawi':
  install_class => 'pabawi::install::docker',
}

class { 'pabawi::proxy::nginx':
  ssl_self_signed => false,
  ssl_cert_source => 'puppet:///modules/site/ssl/pabawi.crt',
  ssl_key_source  => 'puppet:///modules/site/ssl/pabawi.key',
}

class { 'pabawi::install::docker':
  image       => 'pabawi/pabawi:v1.2.3',
  environment => {
    'NODE_ENV' => 'production',
    'PORT'     => '3000',
  },
}
