# frozen_string_literal: true

module Yes
  module Core
    module Utils
      # Notifies about errors via a pluggable error reporter.
      #
      # By default, errors are logged via Rails.logger. To integrate with an external
      # error tracking service (e.g. Sentry), configure the error reporter:
      #
      #   Yes::Core.configure do |config|
      #     config.error_reporter = ->(error, context:) { Sentry.capture_exception(error, extra: context) }
      #   end
      #
      # The error_reporter must respond to #call(error, context:).
      class ErrorNotifier
        # @param event [PgEventstore::Event]
        # @return [void]
        def invalid_event_data(event)
          msg = 'Event with invalid data found in stream'
          data = { event: event.to_json }

          logger&.info("#{msg} data: #{data}")
          capture_message(msg, extra: data)
        end

        # @param error [Error]
        # @return [void]
        def payload_extraction_failed(error)
          msg = 'Large payload extraction failed'

          logger&.info("#{msg} data: #{error.extra}")
          capture_message(msg, extra: error.extra)
        end

        # @param error [Error]
        # @return [void]
        def decryption_key_error(error)
          data = {
            encryptor_response: error.encryptor_response,
            event: error.event
          }

          logger&.info("#{error.message} data: #{data}")
          capture_message(error.message, extra: data)
        end

        # @param error [Error]
        # @return [void]
        def decryption_error(error)
          logger&.info("#{error.message} data: #{error.extra}")
          capture_message(error.message, extra: error.extra)
        end

        # @param message [String]
        # @param event [PgEventstore::Event]
        # @return [void]
        def event_handler_not_defined(message, event)
          data = { event: event.to_json }

          logger&.info("#{message} data: #{data}")
          capture_message(message, extra: data) if ENV['CAPTURE_EVENTSOURCING_ERRORS'] == 'true'
        end

        # @return [void]
        def missing_payload_store_client_error
          msg = 'Missing PayloadStore Client. Please configure it.'

          logger&.info(msg)
          capture_message(msg)
        end

        # @param error [Exception]
        # @param extra [Hash, nil]
        # @return [void]
        def notify(error, extra: nil)
          error_reporter&.call(error, context: extra || {})
        end

        private

        attr_reader :error_reporter, :logger

        def initialize(logger: Yes::Core.configuration.logger)
          @error_reporter = Yes::Core.configuration.error_reporter
          @logger = logger
        end

        # @param msg [String]
        # @param options [Hash]
        # @return [void]
        def capture_message(msg, options = {})
          return unless error_reporter

          error = StandardError.new(msg)
          error_reporter.call(error, context: options.fetch(:extra, {}))
        end
      end
    end
  end
end
