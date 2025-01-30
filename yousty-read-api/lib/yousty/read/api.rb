# frozen_string_literal: true

require 'yousty/read/api/version'
require 'yousty/eventsourcing'
require 'jwt_token_auth_client_rails'
require 'pagy'
require 'api-pagination'
require_relative 'api/model_constraints'
require_relative 'api/api_pagination_patch'

module Yousty
  module Read
    module Api
      class Error < StandardError; end

      class << self
        # @return [ActiveSupport::OrderedOptions]
        def config
          @config ||= ActiveSupport::OrderedOptions.new.tap do |opts|
            opts.read_models = [] # E.g. ['apprenticeships', 'companies', 'professions']
          end
        end

        def configure
          yield config
        end
      end
    end
  end
end

require 'yousty/read/api/engine'
