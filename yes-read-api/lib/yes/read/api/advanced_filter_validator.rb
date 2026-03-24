# frozen_string_literal: true

require 'dry-schema'

module Yes
  module Read
    module Api
      class AdvancedFilterValidator
        PaginationSchema = Dry::Schema.Params do
          required(:size).value(:integer)
          required(:number).value(:integer)
        end

        AdvancedEndpointPayloadSchema = Dry::Schema.Params do
          required(:filter_definition).hash(Yes::Core::ReadModel::FilterQueryBuilder::FilterSetSchema)
          optional(:page).hash(PaginationSchema)
          optional(:order).value(:hash)
          optional(:include).value(:string)
        end

        class << self
          def call(payload)
            new(payload).call
          end
        end

        attr_reader :payload

        def initialize(payload)
          @payload = payload
        end

        def call
          AdvancedEndpointPayloadSchema.call(payload)
        end
      end
    end
  end
end
