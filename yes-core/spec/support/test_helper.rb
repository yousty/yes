# frozen_string_literal: true

class TestHelper
  class << self
    def configure
      Yes::Core.configure do |config|
        config.payload_store_client = DummyPayloadStoreClient.new
      end
    end

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
