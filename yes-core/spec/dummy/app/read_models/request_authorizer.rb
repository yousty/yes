# frozen_string_literal: true

module ReadModels
  class RequestAuthorizer < Yes::Core::Authorization::ReadRequestAuthorizer
    class << self
      def call(_params, _auth_data)
        true
      end
    end
  end
end
