# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

gem 'yes-core', path: 'yes-core'

gem 'rspec'

instance_eval(File.read(File.expand_path('dummy/Gemfile', __dir__)))

source 'https://gem.fury.io/yousty-ag/' do
  gem 'jwt_token_auth_client_rails', '~> 3.3'
  gem 'yousty-api', '~> 1.4' 
  gem 'yousty-eventsourcing', '~> 12'
end

gem 'rails', '~> 7.2'
