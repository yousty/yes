# frozen_string_literal: true

module Yes
  module Core
    # Processes commands asynchronously through ActiveJob
    # @since 0.1.0
    class CommandProcessor < ActiveJob::Base
      queue_as :commands

      # Error raised when a command is not registered with a handler
      UnregisteredCommand = Class.new(Error)

      # @return [Object] The notifier for command processing events
      attr_reader :command_notifiers, :custom_batch_id
      private :command_notifiers, :custom_batch_id

      # Processes the given commands by running them through their respective handlers.
      # @param origin [String] a string identifying the origin of the commands
      # @param command_or_commands [Command, Array<Command>] the command or commands to process
      # @param notifier_options [Hash] options to pass to the command notifier
      # @param custom_batch_id [String] Custom batch ID
      # @return [Array<CommandResponse>] the responses from the performed commands
      # @raise [UnregisteredCommand] if any command lacks a handler
      def perform(origin, command_or_commands, notifier_options, custom_batch_id = nil)
        setup(notifier_options, custom_batch_id)

        commands = [*command_or_commands]
        ensure_guard_evaluators_exist?(commands)

        commands.map! { |cmd| cmd.class.new(cmd.to_h.merge(origin:, batch_id:)) }

        if command_notifiers.any?
          CommandNotifier.with_batch_notification(command_notifiers, batch_id, commands) { run_commands(commands) }
        else
          run_commands(commands)
        end
      end

      private

      # Instantiates the command notifier from the config, using the given options.
      # @param notifier_options [Hash] the options to pass to the command notifier
      # @param custom_batch_id [String] Custom batch ID
      # @return [void]
      def setup(notifier_options, custom_batch_id)
        @command_notifiers = Yousty::Eventsourcing.config.command_notifier_classes&.map do |notifier_class|
          notifier_class.new(notifier_options)
        end || []
        @custom_batch_id = custom_batch_id
      end

      # Runs the given commands through their respective aggregates.
      # @param commands [Array<Command>] the commands to run
      # @return [Array<CommandResponse>] responses from the performed commands
      def run_commands(commands)
        commands.map do |cmd|
          cmd_response = run_command(cmd)
          command_notifiers.each { _1.notify_command_response(cmd_response) }
          cmd_response
        end
      end

      # Executes a single command on its aggregate
      # @param cmd [Command] the command to execute
      # @return [CommandResponse] response from executing the command
      def run_command(cmd)
        command_helper = Yousty::Eventsourcing::CommandHelper.new(cmd)
        aggregate = aggregate_class(cmd).new(cmd.subject_id)
        I18n.with_locale(command_helper.command_locale) do
          aggregate.public_send(command_helper.command_name, **cmd.payload)
        end
      end

      # Determines the aggregate class for a given command
      # @param cmd [Command] The command to find the aggregate class for
      # @return [Class] The aggregate class that handles this command
      # TODO: move to command helper once command helper was moved to yes-core
      def aggregate_class(cmd)
        command_helper = Yousty::Eventsourcing::CommandHelper.new(cmd)

        "#{command_helper.command_context}::#{command_helper.subject}::Aggregate".constantize
      end

      # Checks if a guard evaluator exists for the given command
      # @param cmd [Command] The command to check
      # @return [Boolean] true if a guard evaluator exists
      # @raise [UnregisteredCommand] if no guard evaluator is found for the command
      def guard_evaluator_exists?(cmd)
        command_helper = Yousty::Eventsourcing::CommandHelper.new(cmd)
        klass = Yes::Core.configuration.guard_evaluator_class(command_helper.command_context,
                                                              command_helper.subject,
                                                              command_helper.command_name)

        raise UnregisteredCommand, "Unregistered command: #{cmd.class}" unless klass

        true
      end

      # Ensures handlers exist for all commands
      # @param commands [Array<Command>] The commands to check
      # @return [Boolean] true if handlers exist for all commands
      # @raise [UnregisteredCommand] if any command lacks a handler
      def ensure_guard_evaluators_exist?(commands)
        commands.all? { guard_evaluator_exists?(_1) }
      end

      # Returns the batch id of the current batch.
      # @return [String] the batch id
      def batch_id
        custom_batch_id || job_id
      end
    end
  end
end
