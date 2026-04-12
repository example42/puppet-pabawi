# @summary Configure Pabawi integration with AWS EC2
#
# This class manages the integration between Pabawi and AWS EC2,
# writing configuration to the .env file for EC2 inventory discovery,
# lifecycle management, and provisioning.
#
# Authentication supports three modes:
# 1. Explicit access key + secret key (via settings)
# 2. AWS named profile (via settings)
# 3. Default credential chain (env vars, ~/.aws/credentials, instance profile)
#
# @param enabled
#   Whether the integration is enabled (sets AWS_ENABLED in .env)
#
# @param settings
#   Hash of Pabawi application configuration settings written to .env with AWS_ prefix.
#   Supported keys: access_key_id, secret_access_key, default_region, regions,
#   session_token, profile, endpoint
#
# @example Basic usage with access keys
#   class { 'pabawi::integrations::aws':
#     settings => {
#       'access_key_id'     => 'AKIAIOSFODNN7EXAMPLE',
#       'secret_access_key' => 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY',
#       'default_region'    => 'us-east-1',
#       'regions'           => ['us-east-1', 'eu-west-1'],
#     },
#   }
#
# @example Using AWS profile (recommended for non-EC2 hosts)
#   class { 'pabawi::integrations::aws':
#     settings => {
#       'profile'        => 'pabawi-prod',
#       'default_region' => 'us-east-1',
#       'regions'        => ['us-east-1', 'us-west-2'],
#     },
#   }
#
# @example Using default credential chain (recommended on EC2 with instance profile)
#   class { 'pabawi::integrations::aws':
#     settings => {
#       'default_region' => 'us-east-1',
#     },
#   }
#
# @example Via Hiera
#   pabawi::integrations::aws::enabled: true
#   pabawi::integrations::aws::settings:
#     profile: 'pabawi-prod'
#     default_region: 'us-east-1'
#     regions:
#       - 'us-east-1'
#       - 'eu-west-1'
#
class pabawi::integrations::aws (
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
    $memo + { "AWS_${env_key}" => $transformed }
  }

  # Build environment variable lines
  $env_lines = $env_vars.map |$key, $value| {
    "${key}=${value}"
  }.join("\n")

  # Add configuration to .env file via concat fragment
  concat::fragment { 'pabawi_env_aws':
    target  => 'pabawi_env_file',
    content => @("EOT"),
      # AWS Integration
      AWS_ENABLED=${enabled}
      ${env_lines}
      | EOT
    order   => '27',
  }
}
