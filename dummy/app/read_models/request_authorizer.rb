# frozen_string_literal: true

module ReadModels
  class RequestAuthorizer < Yousty::Eventsourcing::ReadRequestAuthorizer
    class << self
      def call(_params, _auth_data)
        true
      end
    end
  end
end
