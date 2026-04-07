# frozen_string_literal: true

module Dummy
  module ReadModels
    module JobApp
      class OnSomeEvent < Yes::Core::ReadModel::EventHandler
      end

      class OnSomeOtherEvent < Yes::Core::ReadModel::EventHandler
      end

      module DummyContext
        class OnSomeEvent < Yes::Core::ReadModel::EventHandler
        end
      end
    end

    module V23
      module NewJobApp
        class OnSomeEvent < Yes::Core::ReadModel::EventHandler
        end
      end
    end
  end
end
