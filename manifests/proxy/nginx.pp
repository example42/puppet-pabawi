# @summary Configure nginx as a reverse proxy for Pabawi with optional SSL support
#
# This class manages nginx installation, SSL certificate setup, and reverse proxy
# configuration for the Pabawi application.
#
# @param manage_package
#   Whether to manage the nginx package installation. Set to false if nginx is managed elsewhere.
#
# @param ssl_enable
#   Whether to enable SSL/TLS for the proxy
#
# @param ssl_self_signed
#   Whether to generate self-signed certificates (true) or use custom certificates (false)
#
# @param ssl_cert_source
#   Puppet file source for custom SSL certificate (required if ssl_self_signed is false)
#
# @param ssl_key_source
#   Puppet file source for custom SSL private key (required if ssl_self_signed is false)
#
# @param ssl_cert_path
#   Filesystem path where SSL certificate will be stored
#
# @param ssl_key_path
#   Filesystem path where SSL private key will be stored
#
# @param listen_port
#   Port for nginx to listen on (443 for HTTPS, 80 for HTTP)
#
# @param backend_port
#   Port where the Pabawi application is running
#
# @param server_name
#   Server name for nginx virtual host configuration
#
# @example Basic usage with self-signed SSL
#   include pabawi::proxy::nginx
#
# @example Custom SSL certificates
#   class { 'pabawi::proxy::nginx':
#     ssl_self_signed => false,
#     ssl_cert_source => 'puppet:///modules/site/ssl/pabawi.crt',
#     ssl_key_source  => 'puppet:///modules/site/ssl/pabawi.key',
#   }
#
class pabawi::proxy::nginx (
  Boolean $manage_package = true,
  Boolean $ssl_enable = true,
  Boolean $ssl_self_signed = true,
  Optional[String[1]] $ssl_cert_source = undef,
  Optional[String[1]] $ssl_key_source = undef,
  String $ssl_cert_path = '/etc/nginx/ssl/pabawi.crt',
  String $ssl_key_path = '/etc/nginx/ssl/pabawi.key',
  Integer[1, 65535] $listen_port = 443,
  Integer[1, 65535] $backend_port = 3000,
  String[1] $server_name = $facts['fqdn'],
) {
  # Validate SSL configuration
  if $ssl_enable and !$ssl_self_signed {
    unless $ssl_cert_source and $ssl_key_source {
      fail('ssl_cert_source and ssl_key_source must be provided when ssl_self_signed is false')
    }
  }

  # Conditionally manage nginx package
  if $manage_package {
    package { 'nginx':
      ensure => installed,
    }
  }

  # Manage nginx service
  service { 'nginx':
    ensure    => running,
    enable    => true,
    require   => $manage_package ? {
      true    => Package['nginx'],
      default => undef,
    },
    subscribe => File['/etc/nginx/sites-available/pabawi'],
  }

  # Setup SSL if enabled
  if $ssl_enable {
    $ssl_dir = dirname($ssl_cert_path)

    # Ensure SSL directory exists
    file { $ssl_dir:
      ensure => directory,
      mode   => '0755',
      owner  => 'root',
      group  => 'root',
    }

    if $ssl_self_signed {
      # Generate self-signed certificate
      exec { 'generate_pabawi_ssl_cert':
        command => "openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                    -keyout ${ssl_key_path} -out ${ssl_cert_path} \
                    -subj '/CN=${server_name}'",
        path    => ['/usr/bin', '/bin'],
        creates => $ssl_cert_path,
        require => File[$ssl_dir],
      }

      file { $ssl_cert_path:
        ensure  => file,
        mode    => '0644',
        owner   => 'root',
        group   => 'root',
        require => Exec['generate_pabawi_ssl_cert'],
      }

      file { $ssl_key_path:
        ensure  => file,
        mode    => '0600',
        owner   => 'root',
        group   => 'root',
        require => Exec['generate_pabawi_ssl_cert'],
      }
    } else {
      # Deploy custom certificates
      file { $ssl_cert_path:
        ensure => file,
        source => $ssl_cert_source,
        mode   => '0644',
        owner  => 'root',
        group  => 'root',
      }

      file { $ssl_key_path:
        ensure => file,
        source => $ssl_key_source,
        mode   => '0600',
        owner  => 'root',
        group  => 'root',
      }
    }
  }

  # Create nginx virtual host configuration
  if $ssl_enable {
    $listen_directive = "${listen_port} ssl"
    $ssl_config_content = "    ssl_certificate ${ssl_cert_path};
    ssl_certificate_key ${ssl_key_path};
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;"
  } else {
    $listen_directive = $listen_port
    $ssl_config_content = ''
  }

  file { '/etc/nginx/sites-available/pabawi':
    ensure  => file,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
    content => epp('pabawi/nginx_vhost.epp', {
      'listen_directive'     => $listen_directive,
      'server_name'          => $server_name,
      'ssl_config_content'   => $ssl_config_content,
      'backend_port'         => $backend_port,
    }),
    require => $manage_package ? {
      true    => Package['nginx'],
      default => undef,
    },
  }

  # Enable the site
  file { '/etc/nginx/sites-enabled/pabawi':
    ensure  => link,
    target  => '/etc/nginx/sites-available/pabawi',
    require => File['/etc/nginx/sites-available/pabawi'],
    notify  => Service['nginx'],
  }
}
