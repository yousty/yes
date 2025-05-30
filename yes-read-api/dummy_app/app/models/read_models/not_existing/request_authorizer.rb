# frozen_string_literal: true

module ReadModels
  module NotExisting
    class RequestAuthorizer < Yousty::Eventsourcing::ReadRequestAuthorizer
      def self.call(_params, _auth_data)
        true
      end
    end
  end
end
