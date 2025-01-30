# frozen_string_literal: true

module ReadModels
  module Company
    class Authorizer < ReadModels::Authorizer
      class << self
        def call(_record, auth_data)
          raise NotAuthorized, 'You need to be a company admin' unless company_admin?(auth_data)

          true
        end
      end
    end
  end
end
