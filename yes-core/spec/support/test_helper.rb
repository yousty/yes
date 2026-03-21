# frozen_string_literal: true

class TestHelper
  class << self
    def configure
      Yes::Core.configure do |config|
        config.payload_store_client = DummyPayloadStoreClient.new
      end
    end

    def clean_up_config
      Yes::Core.instance_variable_set(:@configuration, nil)
    end
  end
end
