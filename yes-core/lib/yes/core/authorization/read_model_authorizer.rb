# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # @abstract Read model authorizer base class. Subclass and override call method to implement
      # a custom authorizer.
      class ReadModelAuthorizer
        NotAuthorized = Class.new(Yes::Core::Error)

        # Implement this method to authorize a read model.
        # Needs to return true if read model is authorized, otherwise raise NotAuthorized.
        # @param record [ApplicationRecord] record to authorize
        # @param auth_data [Hash] authorization data
        # @return [Boolean] true if read model is authorized
        def self.call(_record, _auth_data)
          raise NotAuthorized
        end
      end
    end
  end
end
