# @summary Validate Pabawi configuration
#
# This function validates a Pabawi configuration hash to ensure
# all required parameters are present and valid.
#
# @param config
#   Configuration hash to validate
#
# @return [Boolean]
#   Returns true if configuration is valid, false otherwise
#
# @example Validate a configuration
#   $config = {
#     'proxy_manage' => true,
#     'proxy_class' => 'pabawi::proxy::nginx',
#   }
#   $valid = pabawi::validate_configuration($config)
#
function pabawi::validate_configuration(Hash $config) >> Boolean {
  # Check for required keys
  $required_keys = ['proxy_manage', 'install_manage']
  
  $required_keys.each |$key| {
    unless $config[$key] =~ NotUndef {
      fail("Configuration missing required key: ${key}")
    }
  }
  
  # Validate proxy_manage is boolean
  unless $config['proxy_manage'] =~ Boolean {
    fail("proxy_manage must be a Boolean, got: ${config['proxy_manage']}")
  }
  
  # Validate install_manage is boolean
  unless $config['install_manage'] =~ Boolean {
    fail("install_manage must be a Boolean, got: ${config['install_manage']}")
  }
  
  # If proxy is managed, validate proxy_class
  if $config['proxy_manage'] {
    if $config['proxy_class'] {
      unless $config['proxy_class'] =~ String[1] {
        fail("proxy_class must be a non-empty String")
      }
      
      unless $config['proxy_class'] =~ /^[a-z][a-z0-9_]*(::[a-z][a-z0-9_]*)*$/ {
        fail("proxy_class must be a valid Puppet class name: ${config['proxy_class']}")
      }
    }
  }
  
  # If installation is managed, validate install_class
  if $config['install_manage'] {
    if $config['install_class'] {
      unless $config['install_class'] =~ String[1] {
        fail("install_class must be a non-empty String")
      }
      
      unless $config['install_class'] =~ /^[a-z][a-z0-9_]*(::[a-z][a-z0-9_]*)*$/ {
        fail("install_class must be a valid Puppet class name: ${config['install_class']}")
      }
    }
  }
  
  # Validate integration flags if present
  if $config['bolt_enable'] {
    unless $config['bolt_enable'] =~ Boolean {
      fail("bolt_enable must be a Boolean")
    }
  }
  
  if $config['puppetdb_enable'] {
    unless $config['puppetdb_enable'] =~ Boolean {
      fail("puppetdb_enable must be a Boolean")
    }
  }
  
  if $config['integrations'] {
    unless $config['integrations'] =~ Hash {
      fail("integrations must be a Hash")
    }
    
    $config['integrations'].each |$name, $enabled| {
      unless $enabled =~ Boolean {
        fail("Integration '${name}' must have a Boolean value")
      }
    }
  }
  
  # All validations passed
  true
}
