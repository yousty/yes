# frozen_string_literal: true

module ReadModels
  class Authorizer < Yes::Core::Authorization::ReadModelAuthorizer
    NotAuthorized = Yes::Core::Authorization::ReadModelsAuthorizer::NotAuthorized

    class << self
      private

      def company_admin?(_auth_data)
        true
      end
    end
  end
end
