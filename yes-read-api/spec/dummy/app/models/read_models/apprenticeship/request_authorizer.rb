# frozen_string_literal: true

module ReadModels
  module Apprenticeship
    class RequestAuthorizer < Yes::Core::Authorization::ReadRequestAuthorizer
      def self.call(_params, _auth_data)
        true
      end
    end
  end
end
