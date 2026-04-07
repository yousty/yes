# frozen_string_literal: true

require 'jsonapi/serializer'

module Yes
  module Core
    # Base JSON:API serializer for read models.
    #
    # All auto-generated and user-defined serializers inherit from this class.
    # Wraps the jsonapi-serializer gem.
    #
    # @example
    #   class UserSerializer < Yes::Core::Serializer
    #     set_type 'users'
    #     attributes :id, :email, :first_name, :last_name
    #   end
    class Serializer
      include JSONAPI::Serializer
    end
  end
end
