# frozen_string_literal: true

module Yes
  module Core
    module PayloadStore
      # Base class for payload store operations providing shared error handling
      # and client access.
      class Base
        private

        # @param response [Object] the payload store response
        # @param events [Object] the events associated with the request
        # @return [Boolean] true if the response was an error
        def handle_payload_store_error(response, events)
          return false if response.success?

          msg = "Payload Store error for class: #{self.class.name}"
          error = Yes::Core::PayloadStore::Errors::ClientError.new(
            msg, extra: { payload_store_response: response.failure, events: }
          )
          Yes::Core::Utils::ErrorNotifier.new.payload_extraction_failed(error)

          true
        end

        # @return [Object] the configured payload store client
        def payload_store_client
          @payload_store_client ||= Yes::Core.configuration.payload_store_client
        end
      end
    end
  end
end
