# frozen_string_literal: true

module Yes
  module Read
    module Api
      class Engine < ::Rails::Engine
        isolate_namespace Yes::Read::Api
        config.generators.api_only = true

        config.generators do |g|
          g.test_framework :rspec
        end
        config.yes_read_api = Yes::Read::Api.config
      end
    end
  end
end
