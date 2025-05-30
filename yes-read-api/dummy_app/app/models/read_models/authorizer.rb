# frozen_string_literal: true

module ReadModels
  class Authorizer < Yousty::Eventsourcing::ReadModelAuthorizer
    NotAuthorized = Yousty::Eventsourcing::ReadModelsAuthorizer::NotAuthorized

    class << self
      private

      def company_admin?(_auth_data)
        true
      end
    end
  end
end
