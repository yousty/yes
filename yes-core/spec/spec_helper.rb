# frozen_string_literal: true

require 'pg_eventstore/rspec/test_helpers'

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

  SimpleCov.minimum_coverage 90

  SimpleCov.start 'yes-core'
end

RSpec.configure do |config|
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
