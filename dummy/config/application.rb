# frozen_string_literal: true

require 'rails'
require 'active_record'
require 'yes'

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = false
    config.active_support.deprecation = :log

    # Add database configuration
    config.paths['config/database'] = ['config/database.yml']
    config.paths.add 'db/migrate', with: 'db/migrate'
  end
end
