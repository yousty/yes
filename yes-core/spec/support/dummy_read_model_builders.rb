# frozen_string_literal: true

module Dummy
  module ReadModels
    module JobApp
      class Builder < Yes::Core::ReadModel::Builder
      end
    end

    module V23
      module NewJobApp
        class Builder < Yes::Core::ReadModel::Builder
        end
      end
    end

    # Read model table has a `revision` column
    module TestUser
      class Builder < Yes::Core::ReadModel::Builder
      end

      # Builder for events that map to no read model row; its handler accepts a nil read model
      class NoRowBuilder < Yes::Core::ReadModel::Builder
        NoRowHandler = Struct.new(:read_model) do
          def call(event)
            event
          end
        end

        protected

        def handler_class(_event)
          NoRowHandler
        end

        private

        def read_model(_event)
          nil
        end
      end
    end

    # Read model table has only per-aggregate revision columns and no `revision` column
    module SharedProfileReadModel
      class Builder < Yes::Core::ReadModel::Builder
      end
    end
  end

  module InvalidModuleStructure
    module JobApp
      class Builder < Yes::Core::ReadModel::Builder
      end
    end
  end
end

module ReadModels
  module Apprenticeship
    module EventHandlers
      # Builder scoped within Dummy context so the regex matches
      # Class name: Dummy::ReadModels::Apprenticeship::EventHandlers::Builder
      # See Dummy module below
    end
  end
end

module Dummy
  module ReadModels
    module Apprenticeship
      module EventHandlers
        class Builder < Yes::Core::ReadModel::Builder
        end

        module ApprenticeshipPresentation
          # Event handler for ApprenticeshipCompanyAssigned events
          class OnApprenticeshipCompanyAssigned < Yes::Core::ReadModel::EventHandler
            # @param event [Yes::Core::Event]
            # @return [void]
            def call(event)
              super
              read_model.update!(company_id: event.data['company_id'])
            end
          end
        end
      end
    end
  end
end
