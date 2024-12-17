# frozen_string_literal: true

require 'bundler/setup'
require 'rails'
require 'rails/generators'
require 'generator_spec'
require 'database_cleaner/active_record'

# Set up Rails configuration
ENV['RAILS_ENV'] = 'test'
dummy_app_path = File.expand_path('../dummy', __dir__)

# Configure Rails application before requiring environment
require File.expand_path('../dummy/config/application', __dir__)
require File.expand_path('../dummy/app/contexts/test/user/aggregate', __dir__)
Rails.application.config.root = Pathname.new(dummy_app_path)
Rails.application.config.paths['config/database'] = [File.join(dummy_app_path, 'config/database.yml')]

# Now load the environment
require File.expand_path('../dummy/config/environment.rb', __dir__)

require 'yes'

PgEventstore.configure do |config|
  config.pg_uri = ENV.fetch('PG_EVENTSTORE_URI') { 'postgresql://postgres:postgres@localhost:5532/eventstore' }
  config.connection_pool_size = 20
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
