# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module User
          # @see Yes::Core::ReadModel::EventHandler
          class OnPrincipalRoleAdded < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(event)
              user = Yes::Auth::Principals::User.find_or_create_by(id: event.data['principal_id'])
              role = Yes::Auth::Principals::Role.find_or_create_by(id: event.data['role_id'])
              user.roles << role
            rescue ActiveRecord::RecordNotUnique
              Rails.logger.info("Role(#{event.data['role_id']}) already added to user(#{event.data['principal_id']})")
            end
          end
        end
      end
    end
  end
end
