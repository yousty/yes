# frozen_string_literal: true

module Yes
  module Core
    module TestSupport
      # Utility class for configuring and cleaning up Yes::Core in tests.
      class TestHelper
        class << self
          # Resets the Yes::Core configuration to a clean state.
          # @return [void]
          def clean_up_config
            Yes::Core.instance_variable_set(:@configuration, nil)
          end
        end
      end
    end
  end
end
