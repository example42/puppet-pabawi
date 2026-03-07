# frozen_string_literal: true

source 'https://rubygems.org'

gem 'puppet', ENV['PUPPET_GEM_VERSION'] || '~> 7.0'
gem 'facter', '>= 2.4.0'

group :test do
  gem 'puppetlabs_spec_helper', '~> 8.0'
  gem 'rspec-puppet', '~> 5.0'
  gem 'rspec-puppet-facts', '~> 5.0'
  gem 'puppet-lint', '~> 4.0'
  gem 'metadata-json-lint', '~> 4.0'
  gem 'puppet-syntax', '~> 4.0'
end

group :development do
  gem 'puppet-blacksmith', '~> 7.0'
end
