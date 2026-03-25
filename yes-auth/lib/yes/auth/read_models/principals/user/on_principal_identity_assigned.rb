# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module User
          # @see Yes::Core::ReadModel::EventHandler
          class OnPrincipalIdentityAssigned < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(event)
              read_model.update_columns(identity_id: event.data['identity_id'])
            end
          end
        end
      end
    end
  end
end
