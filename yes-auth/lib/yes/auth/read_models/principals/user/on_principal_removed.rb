# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module User
          # @see Yes::Core::ReadModel::EventHandler
          class OnPrincipalRemoved < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(_event)
              read_model.delete
            end
          end
        end
      end
    end
  end
end
