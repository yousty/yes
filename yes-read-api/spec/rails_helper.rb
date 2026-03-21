# frozen_string_literal: true

ENV['RAILS_ENV'] = 'test'

require 'rails/all'
require 'yes/read/api'
require_relative 'spec_helper'
require File.expand_path('dummy/config/environment', __dir__)

abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'

Dir[File.join(__dir__, 'support/**/*.rb')].each { |f| load f }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!

  config.include JwtHelpers, type: :request
  config.include APIHelpers, type: :request
end
