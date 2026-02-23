# frozen_string_literal: true

source 'https://rubygems.org'

gem 'puppet', ENV['PUPPET_GEM_VERSION'] || '~> 6.0'
gem 'facter', '>= 2.4.0'

group :test do
  gem 'puppetlabs_spec_helper', '~> 6.0'
  gem 'rspec-puppet', '~> 2.0'
  gem 'rspec-puppet-facts', '~> 2.0'
  gem 'puppet-lint', '~> 3.0'
  gem 'metadata-json-lint', '~> 3.0'
  gem 'puppet-syntax', '~> 3.0'
end

group :development do
  gem 'puppet-blacksmith', '~> 6.0'
end
