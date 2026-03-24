# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

# SimpleCov must start before any app code is loaded
if ENV['TEST_COVERAGE'] == 'true'
  require 'simplecov'
  require 'simplecov-formatter-badge'

  SimpleCov.profiles.define 'yes-core' do
    add_filter 'spec/'
    add_filter 'lib/yes/core/version.rb'
    add_group 'Gem', 'lib'
    track_files 'lib/**/*.rb'
  end

  SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
    [
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::BadgeFormatter
    ]
  )

  SimpleCov.minimum_coverage 50

  SimpleCov.start 'yes-core'
end

require 'rails/all'
require 'yes/core'
require_relative 'spec_helper'
require File.expand_path('dummy/config/environment', __dir__)

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'factory_bot'

FactoryBot.definition_file_paths = [File.expand_path('factories', __dir__)]
FactoryBot.find_definitions

Dir[File.join(__dir__, 'support/**/*.rb')].each { |f| load f }

# Skip maintain_test_schema! for SQL format as it causes issues with structure.sql
if Rails.application.config.active_record.schema_format != :sql
  begin
    ActiveRecord::Migration.maintain_test_schema!
  rescue ActiveRecord::PendingMigrationError => e
    abort e.to_s.strip
  end
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.after do
    PgEventstore::TestHelpers.clean_up_db
    TestHelper.clean_up_config
  end
end
