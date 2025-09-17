# frozen_string_literal: true


# require 'yousty/eventsourcing'
# require 'jwt_token_auth_client_rails'
# require 'pagy'
# require 'api-pagination'
# require_relative 'api/model_constraints'
# require_relative 'api/api_pagination_patch'

require 'yousty/eventsourcing'
require 'zeitwerk'
require 'yousty/api' # for serializers

module Yes
  module Read
    module Api
      class Error < StandardError; end

      class << self
        def loader
          @loader ||= begin
            loader = Zeitwerk::Loader.new
            loader.tag = 'yes-read-api'
            loader.push_dir(File.expand_path('../..', __dir__))
            loader.ignore("#{File.expand_path('..', __dir__)}/read/api/version.rb")
            loader.setup
            loader
          end
        end

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

require 'yes/read/api/version'

Yes::Read::Api.loader.eager_load
