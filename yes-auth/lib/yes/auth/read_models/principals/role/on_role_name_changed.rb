# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module Role
          # @see Yes::Core::ReadModel::EventHandler
          class OnRoleNameChanged < Yes::Core::ReadModel::EventHandler
            def call(event)
              super

              read_model.update_columns(name: event.data['name'])
            end
          end
        end
      end
    end
  end
end
