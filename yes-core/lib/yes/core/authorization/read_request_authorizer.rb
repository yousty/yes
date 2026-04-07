# frozen_string_literal: true

module Yes
  module Core
    module Authorization
      # @abstract Read request authorizer base class. Subclass and override call method to implement
      # a custom authorizer.
      class ReadRequestAuthorizer
        NotAuthorized = Class.new(Yes::Core::Error)

        class << self
          # Implement this method to authorize a read request.
          # Needs to return true if read request is authorized, otherwise raise NotAuthorized.
          # @param params [Hash] request params to authorize
          # @param auth_data [Hash] authorization data
          # @return [Boolean] true if read request is authorized raises NotAuthorized otherwise
          def call(_params, _auth_data)
            raise NotAuthorized
          end

          private

          # @param auth_data [Hash] authorization data
          # @return [Boolean] true if user is a super admin
          def super_admin?(auth_data)
            Yes::Core.configuration.super_admin_check.call(auth_data)
          end
        end
      end
    end
  end
end
