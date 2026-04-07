# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module WriteResourceAccess
          # @see Yes::Core::ReadModel::EventHandler
          class OnWriteResourceAccessPrincipalAssigned < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(event)
              read_model.update_columns(principal_id: event.data['principal_id'])
            end
          end
        end
      end
    end
  end
end
