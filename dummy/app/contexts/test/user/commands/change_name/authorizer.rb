# frozen_string_literal: true

module Test
  module User
    module Commands
      module ChangeName
        class Authorizer < ::Yousty::Eventsourcing::CommandAuthorizer
          def self.call(_command, _auth_data)
            true
          end
        end
      end
    end
  end
end
