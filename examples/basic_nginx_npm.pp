# Example: Basic installation with nginx proxy and npm
#
# This example demonstrates the simplest Pabawi installation using
# default settings with nginx as a reverse proxy and npm for installation.

include pabawi

# This will:
# - Install and configure nginx with self-signed SSL certificates
# - Clone the Pabawi repository
# - Install Node.js and npm dependencies
# - Create a systemd service for Pabawi
# - Start the Pabawi application
