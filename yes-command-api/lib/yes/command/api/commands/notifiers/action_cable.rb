# frozen_string_literal: true

module Yes
  module Command
    module Api
      module Commands
        module Notifiers
          # Notifies command processing events via ActionCable broadcast.
          # Used with an external WebSocket gateway (e.g. socket_gate).
          class ActionCable < Yes::Core::Commands::Notifier
            # @param batch_id [String] the id of the batch that has started processing
            # @param transaction [TransactionDetails] the transaction details
            # @param commands [Array<Command>] the commands being processed
            def notify_batch_started(batch_id, transaction = nil, commands = nil)
              ::ActionCable.server.broadcast(
                channel,
                {
                  batch_id:,
                  published_at:,
                  type: 'batch_started',
                  transaction: transaction.to_h
                }.merge(commands_data(commands))
              )
            end

            # @param batch_id [String] the id of the batch that has finished processing
            # @param transaction [TransactionDetails] the transaction details
            # @param responses [Array<Response>] the command responses
            def notify_batch_finished(batch_id, transaction = nil, responses = nil)
              ::ActionCable.server.broadcast(
                channel,
                {
                  batch_id:,
                  published_at:,
                  type: 'batch_finished',
                  transaction: transaction.to_h
                }.merge(failed_commands_data(responses))
              )
            end

            # @param cmd_response [Yes::Core::Commands::Response] the command response
            def notify_command_response(cmd_response)
              ::ActionCable.server.broadcast(
                channel,
                cmd_response.to_notification.merge(published_at:)
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
  end
end
