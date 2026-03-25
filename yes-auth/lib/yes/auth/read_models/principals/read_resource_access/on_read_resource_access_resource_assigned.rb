# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module ReadResourceAccess
          # @see Yes::Core::ReadModel::EventHandler
          class OnReadResourceAccessResourceAssigned < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(event)
              read_model.update_columns(resource_id: event.data['resource_id'])
            end
          end
        end
      end
    end
  end
end
