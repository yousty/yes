# frozen_string_literal: true

module Yousty
  module Read
    module Api
      class Engine < ::Rails::Engine
        isolate_namespace Yousty::Read::Api
        config.generators.api_only = true

        config.generators do |g|
          g.test_framework :rspec
        end
        config.yousty_read_api = Yousty::Read::Api.config
      end
    end
  end
end
