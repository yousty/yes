# frozen_string_literal: true

module Yes
  module Command
    module Api
      class Engine < ::Rails::Engine
        isolate_namespace Yes::Command::Api
        config.generators.api_only = true

        config.generators do |g|
          g.test_framework :rspec
        end
      end
    end
  end
end
