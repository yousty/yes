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
            config = Yes::Core.configuration
            config.aggregate_shortcuts = false
            config.super_admin_check = ->(_auth_data) { false }
            config.logger = nil
            config.error_reporter = nil
            config.payload_store_client = nil
            config.process_commands_inline = true
            config.command_notifier_classes = []
            config.otl_tracer = nil
            config.auth_adapter = nil
          end
        end
      end
    end
  end
end
