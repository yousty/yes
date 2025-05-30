# frozen_string_literal: true

source 'https://rubygems.org'

ruby '3.3.6'

gem 'rake', '~> 13.0'

gem 'rails', '~> 7.2'

# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'
# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 6.4'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: %i[mingw mswin x64_mingw jruby]

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

source 'https://gem.fury.io/yousty-ag/' do
  gem 'jwt_token_auth_client_rails', '~> 3.3'
  gem 'yousty-api', '~> 1.4'
  gem 'yousty-eventsourcing', '~> 14'
end

gem 'database_cleaner-active_record'
gem 'generator_spec'
gem 'rspec', '~> 3.0'
gem 'rspec-rails', '~> 7.1'
gem 'rubocop', '~> 1.21'
gem 'rubocop-performance'
gem 'rubocop-rails'

gem 'yes-command-api', path: 'yes-command-api'
gem 'yes-core', path: 'yes-core'
gem 'yes-read-api', path: 'yes-read-api'
