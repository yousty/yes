# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module ReadResourceAccess
          # @see Yes::Core::ReadModel::EventHandler
          class OnReadResourceAccessServiceChanged < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(event)
              read_model.update_columns(service: event.data['service'])
            end
          end
        end
      end
    end
  end
end
