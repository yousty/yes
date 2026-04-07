# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module WriteResourceAccess
          # @see Yes::Core::ReadModel::EventHandler
          class OnWriteResourceAccessAttributeChanged < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(event)
              auth_attributes = read_model.auth_attributes || {}
              auth_attributes[event.data['name']] = event.data['value']

              read_model.update_columns(auth_attributes:)
            end
          end
        end
      end
    end
  end
end
