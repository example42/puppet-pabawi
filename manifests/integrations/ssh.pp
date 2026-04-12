# @summary Configure Pabawi integration with SSH
#
# This class manages the integration between Pabawi and SSH,
# writing connection pool and execution defaults to the .env file.
#
# @param enabled
#   Whether the integration is enabled (sets SSH_ENABLED in .env)
#
# @param settings
#   Hash of SSH configuration settings written to .env with SSH_ prefix.
#   Supported keys: config_path, default_user, default_port, default_key,
#   host_key_check, connection_timeout, command_timeout, max_connections,
#   max_connections_per_host, idle_timeout, concurrency_limit,
#   sudo_enabled, sudo_command, sudo_passwordless, sudo_user, priority
#
# @example Basic usage
#   class { 'pabawi::integrations::ssh':
#     settings => {
#       'default_user'       => 'automation',
#       'default_port'       => 22,
#       'default_key'        => '/opt/pabawi/ssh/id_ed25519',
#       'host_key_check'     => true,
#       'connection_timeout' => 30,
#       'command_timeout'    => 300,
#       'max_connections'    => 50,
#       'concurrency_limit'  => 10,
#     },
#   }
#
# @example Via Hiera
#   pabawi::integrations::ssh::enabled: true
#   pabawi::integrations::ssh::settings:
#     default_user: 'automation'
#     default_port: 22
#     default_key: '/opt/pabawi/ssh/id_ed25519'
#     host_key_check: true
#     connection_timeout: 30
#     max_connections: 50
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
      SSH_ENABLED=${enabled}
      ${env_lines}
      | EOT
    order   => '25',
  }
}
