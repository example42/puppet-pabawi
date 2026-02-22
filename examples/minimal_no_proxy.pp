# Example: Minimal installation without proxy
#
# This example shows how to install Pabawi without nginx proxy,
# useful when you have an external load balancer or proxy.

class { 'pabawi':
  proxy_manage => false,
}

# This will only:
# - Install Pabawi using npm (default)
# - Start the Pabawi application on port 3000
# - No nginx proxy will be configured
