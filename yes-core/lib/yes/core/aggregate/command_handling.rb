# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      # Provides command handling functionality for aggregates
      module CommandHandling
        extend ActiveSupport::Concern

        private

        # Handles a command using the specified handler class
        # @param command [Object] The command to be handled
        # @param handler_class [Class] The handler class to process the command
        # @return [Boolean] true if command was handled successfully
        # @raise [CommandHandler::InvalidTransition] If the command transition is invalid
        # @raise [CommandHandler::NoChangeTransition] If the command results in no change
        # @raise [Yousty::Eventsourcing::Command::Invalid] If the command is invalid
        def handle_command(command, handler_class)
          command_helper = Yousty::Eventsourcing::CommandHelper.new(command)

          handler_class.new(command, publish_events: false).call

          send(:"#{command_helper.command_name.underscore}_error=", nil)

          true
        rescue CommandHandler::InvalidTransition,
               CommandHandler::NoChangeTransition,
               Yousty::Eventsourcing::Command::Invalid => e
          send(:"#{command_helper.command_name.underscore}_error=", e.message)
          raise e
        end

        # Executes a command within a transaction, handling errors and publishing events
        # @param cmd [Object] The command to execute
        # @param handler_class [Class] The handler class to process the command
        # @return [Yousty::Eventsourcing::Stateless::CommandResponse] The command response
        # @return [Yousty::Eventsourcing::Stateless::CommandResponse] with error if command handling fails
        def execute_command(cmd, handler_class)
          PgEventstore.client.multiple do
            handle_command(cmd, handler_class)

            handler = handler_class.new(cmd, revision_check: false)
            # only run base class call method which publishes events
            CommandHandler.instance_method(:call).bind_call(handler)

            command_response_class(cmd).new(cmd:)
          end
        rescue CommandHandler::InvalidTransition,
               CommandHandler::NoChangeTransition,
               Yousty::Eventsourcing::Command::Invalid => e

          command_response_class(cmd).new(cmd:, error: e)
        end

        def command_response_class(cmd)
          cmd.is_a?(Yousty::Eventsourcing::CommandGroup) ? CommandGroupResponse : CommandResponse
        end
      end
    end
  end
end
