# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # Authorizes a collection of read model records by delegating to per-record authorizers.
      class ReadModelsAuthorizer
        NotAuthorized = Class.new(Yes::Core::Error)

        class << self
          # @param read_model_name [String] name of the read model
          # @param records [Array<ApplicationRecord>] records to authorize
          # @param auth_data [Hash] authorization data
          # @raise [NotAuthorized] if any records are not authorized
          def call(read_model_name, records, auth_data)
            authorizer = authorizer_for(read_model_name)

            return unless authorizer

            unauthorized = []
            records.each do |record|
              authorizer.call(record, auth_data)
            rescue ReadModelAuthorizer::NotAuthorized => e
              unauthorized << {
                message: e.message,
                model_type: record.class.to_s,
                model_id: record.id
              }
            end

            raise NotAuthorized.new(extra: unauthorized) if unauthorized.any?
          end

          private

          # @param read_model_name [String] name of the read model
          # @return [Yes::Core::Authorization::ReadModelAuthorizer, nil] authorizer for read model if existing
          def authorizer_for(read_model_name)
            class_name = "ReadModels::#{read_model_name.classify}::Authorizer"

            Kernel.const_get(class_name)
          rescue NameError
            nil # defining a per record authorizer is optional
          end
        end
      end
    end
  end
end
