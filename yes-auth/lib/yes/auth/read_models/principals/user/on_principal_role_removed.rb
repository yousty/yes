# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module User
          # @see Yes::Core::ReadModel::EventHandler
          class OnPrincipalRoleRemoved < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(event)
              user = Yes::Auth::Principals::User.find_by(id: event.data['principal_id'])
              role = Yes::Auth::Principals::Role.find_by(id: event.data['role_id'])
              return unless user && role

              user.roles.delete(role)
            end
          end
        end
      end
    end
  end
end
