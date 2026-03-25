# frozen_string_literal: true

# @abstract Command notifier base class. Subclass and override notification methods to implement
# a custom notifier.
module Yes
  module Core
    module Commands
      class Notifier
        attr_reader :channel
        private :channel

        # @param options [Hash] notifier options
        # @option options [String] :channel the notification channel
        def initialize(options = {})
          @channel = options[:channel]
        end

        # Implement this method to notify that a batch has started processing
        # @param batch_id [String] batch id of the batch that has started processing
        # @param transaction [TransactionDetails] the transaction details of the current transaction
        # @param commands [Array<Command>] the commands that are being processed
        def notify_batch_started(batch_id, transaction = nil, commands = nil)
          raise NotImplementedError
        end

        # Implement this method to notify that a batch has finished processing
        # @param batch_id [String] batch id of the batch that has finished processing
        # @param transaction [TransactionDetails] the transaction details of the current transaction
        # @param responses [Array<Response>] the responses of the commands that were processed
        def notify_batch_finished(batch_id, transaction = nil, responses = nil)
          raise NotImplementedError
        end

        # Implement this method to notify that a command response has been received
        # @param cmd_response [Yes::Core::Commands::Response] the command response to notify
        def notify_command_response(cmd_response)
          raise NotImplementedError
        end

        # Wraps the given block in a batch notification.
        # @param batch_id [String] the batch id
        # @param commands [Array<Command>] the commands being processed in the batch
        # @param transaction [TransactionDetails] the transaction details of the current transaction
        # @yield executes commands within the batch notification
        # @yieldreturn [Array<Response>] responses from the executed commands
        # @return [Array<Response>] responses from the executed commands
        def with_batch_notification(batch_id, commands, transaction = nil)
          notify_batch_started(batch_id, transaction, commands)
          response = yield
          notify_batch_finished(batch_id, transaction, response)

          response
        end

        def self.with_batch_notification(notifiers, batch_id, commands, transaction = nil)
          notifiers.each { _1.notify_batch_started(batch_id, transaction, commands) }
          response = yield
          notifiers.each { _1.notify_batch_finished(batch_id, transaction, response) }

          response
        end
      end
    end
  end
end
