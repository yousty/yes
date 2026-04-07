# frozen_string_literal: true

module ReadModels
  module JobApp
    # Per-record authorizer for JobApp read model
    class Authorizer < Yes::Core::Authorization::ReadModelAuthorizer
      # @param record [ApplicationRecord] record to authorize
      # @param _auth_data [Hash] authorization data
      # @return [Boolean] true if record is authorized
      # @raise [NotAuthorized] if record is not persisted
      def self.call(record, _auth_data)
        raise NotAuthorized, 'Record not persisted' unless record.persisted?

        true
      end
    end
  end
end
