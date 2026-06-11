# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        module ReadResourceAccess
          # Rebuilds the mirror row after the aggregate was restored.
          #
          # The row was hard-deleted by {OnReadResourceAccessRemoved}; the
          # builder recreates it blank during read-model resolution, and the
          # stream replay fills the attributes back in (see {RestoreReplay}).
          class OnReadResourceAccessRestored < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(_event)
              RestoreReplay.new(builder: Builder.new, stream_name: 'ReadResourceAccess').call(read_model)
            end
          end
        end
      end
    end
  end
end
