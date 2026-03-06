# @summary Configure Pabawi integration with SSH
#
# This class manages the integration between Pabawi and SSH,
# including SSH connection configuration and .env file settings.
#
# @param enabled
#   Whether the integration is enabled (sets SSH_ENABLED in .env)
#
# @param settings
#   Hash of SSH configuration settings that will be written to .env file
#   with SSH_ prefix. Supported keys include:
#   - host: SSH host to connect to
#   - port: SSH port (default 22)
#   - username: SSH username
#   - private_key_path: Path to SSH private key
#   - timeout: Connection timeout in milliseconds
#   - known_hosts_path: Path to known_hosts file
#
# @example Basic usage
#   class { 'pabawi::integrations::ssh':
#     enabled  => true,
#     settings => {
#       'host'             => 'remote.example.com',
#       'port'             => 22,
#       'username'         => 'automation',
#       'private_key_path' => '/opt/pabawi/ssh/id_rsa',
#       'timeout'          => 30000,
#     },
#   }
#
# @example Via Hiera
#   pabawi::integrations::ssh::enabled: true
#   pabawi::integrations::ssh::settings:
#     host: 'remote.example.com'
#     port: 22
#     username: 'automation'
#     private_key_path: '/opt/pabawi/ssh/id_rsa'
#     timeout: 30000
#     known_hosts_path: '/opt/pabawi/ssh/known_hosts'
#
class pabawi::integrations::ssh (
  Boolean $enabled = true,
  Hash $settings = {},
) {
  # Transform settings hash values to .env format
  # Arrays -> JSON, Booleans -> lowercase strings, Integers -> strings, undef/empty -> 'not-set'
  $env_vars = $settings.reduce({}) |$memo, $pair| {
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
    $memo + { "SSH_${env_key}" => $transformed }
  }

  # Build environment variable lines
  $env_lines = $env_vars.map |$key, $value| {
    "${key}=${value}"
  }.join("\n")

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_ssh':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # SSH Integration
      SSH_ENABLED=${enabled ? { true => 'true', false => 'false' }}
      ${env_lines}
      | EOT
    order   => '25',
  }
}
