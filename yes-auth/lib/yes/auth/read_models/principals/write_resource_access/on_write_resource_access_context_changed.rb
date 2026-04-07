# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module WriteResourceAccess
          # @see Yes::Core::ReadModel::EventHandler
          class OnWriteResourceAccessContextChanged < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(event)
              read_model.update_columns(context: event.data['context'])
            end
          end
        end
      end
    end
  end
end
