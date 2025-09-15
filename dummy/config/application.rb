# frozen_string_literal: true

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.1
    config.eager_load = false
    config.active_support.deprecation = :log

    # Use SQL schema format to preserve database-specific features like triggers
    config.active_record.schema_format = :sql

    # Add database configuration
    config.paths['config/database'] = ['config/database.yml']
    config.paths.add 'db/migrate', with: 'db/migrate'
    config.i18n.available_locales = %i[en de-CH fr-CH it-CH]
    config.i18n.default_locale = :'de-CH'
  end
end
