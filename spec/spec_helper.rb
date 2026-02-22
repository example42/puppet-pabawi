# frozen_string_literal: true

require 'puppetlabs_spec_helper/module_spec_helper'
require 'rspec-puppet-facts'

include RspecPuppetFacts

# Configure RSpec
RSpec.configure do |c|
  c.hiera_config = 'spec/fixtures/hiera.yaml'
  c.mock_with :rspec
  
  # Default facts for all tests
  c.default_facts = {
    os: {
      family: 'Debian',
      name: 'Ubuntu',
      release: {
        major: '20',
        full: '20.04',
      },
    },
    osfamily: 'Debian',
    operatingsystem: 'Ubuntu',
    operatingsystemrelease: '20.04',
    kernel: 'Linux',
    fqdn: 'test.example.com',
    hostname: 'test',
    domain: 'example.com',
    path: '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
  }
  
  # Coverage reporting
  c.after(:suite) do
    RSpec::Puppet::Coverage.report!
  end
end

# Puppet configuration
Puppet::Util::Log.level = :warning
Puppet::Util::Log.newdestination(:console)
