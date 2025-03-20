# frozen_string_literal: true

module Yes
  module Core
    module CommandNotifiers
      class MessageBusNotifier < Yes::Core::CommandNotifier
        attr_reader :channel
        private :channel

        # @param options [Hash] the options to create a notifier with
        # @option options [String] :channel the channel name to publish notifications to
        def initialize(options)
          super()

          @channel = options[:channel]
        end

        # @param batch_id [String] the id of the batch that has started processing
        # @param transaction [TransactionDetails] the transaction details of the current transaction
        # @param commands [Array<Command>] the commands that are being processed
        #
        def notify_batch_started(batch_id, transaction = nil, commands = nil)
          user_ids = [transaction&.caller_id].compact

          data =
            {
              batch_id:, published_at:, type: 'batch_started'
            }.merge(
              transaction: transaction.to_h
            ).merge(commands_data(commands))

          ::MessageBus.publish(channel, data, user_ids: user_ids.empty? ? nil : user_ids)
        end

        # @param batch_id [String] the id of the batch that has finished processing
        # @param transaction [TransactionDetails] the transaction details of the current transaction
        # @param responses [Array<CommandResponse>] the responses of the commands that were processed
        #
        def notify_batch_finished(batch_id, transaction = nil, responses = nil)
          user_ids = [transaction&.caller_id].compact

          data = {
            type: 'batch_finished',
            batch_id:,
            published_at:
          }.merge(
            transaction: transaction.to_h
          ).merge(failed_commands_data(responses))

          ::MessageBus.publish(channel, data, user_ids: user_ids.empty? ? nil : user_ids)
        end

        # @param cmd_response [Yousty::Eventsourcing::CommandResponse]
        #   the command response to notify
        def notify_command_response(cmd_response)
          user_ids = [cmd_response.transaction&.caller_id].compact

          ::MessageBus.publish(
            channel,
            cmd_response.to_notification.merge(published_at:),
            user_ids: user_ids.empty? ? nil : user_ids
          )
        end

        private

        # @return [Integer]
        def published_at
          Time.now.to_i
        end

        def commands_data(commands)
          return {} if commands.nil?

          { commands: commands.map { { command: _1.class.to_s, command_id: _1.command_id } } }
        end

        def failed_commands_data(responses)
          return {} if responses.nil?

          failed = responses.filter_map do |resp|
            next unless resp.error

            {
              command: resp.cmd.class.to_s,
              command_id: resp.cmd.command_id,
              error: resp.error.to_s
            }
          end

          failed.empty? ? {} : { failed_commands: failed }
        end
      end
    end
  end
end
