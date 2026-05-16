# frozen_string_literal: true

module Yes
  module Core
    module Commands
      # Processes commands asynchronously through ActiveJob
      # @since 0.1.0
      class Processor < ActiveJob::Base
        include Yes::Core::OpenTelemetry::Trackable

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
        # @return [Array<Response>] the responses from the performed commands
        # @raise [UnregisteredCommand] if any command lacks a handler
        def perform(origin, command_or_commands, notifier_options, custom_batch_id = nil, inline = false)
          setup(notifier_options, custom_batch_id, inline)
          singleton_class.current_span&.add_event('Command Processor Setup Done')

          commands = [*command_or_commands]
          ensure_guard_evaluators_exist?(commands)
          singleton_class.current_span&.add_event('Ensured Guard Evaluators Exist')

          commands.map! { |cmd| reinstantiate_with_reserved_keys(cmd, origin:, batch_id:) }
          singleton_class.current_span&.add_event('Commands Mapped')

          if command_notifiers.any?
            singleton_class.with_otl_span 'Run Commands With Notifiers' do
              Notifier.with_batch_notification(command_notifiers, batch_id, commands) do
                singleton_class.with_otl_span 'Run Commands' do
                  run_commands(commands)
                end
              end
            end
          else
            singleton_class.with_otl_span 'Run Commands' do
              run_commands(commands)
            end
          end
        end
        otl_trackable :perform, Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Command Processor Perform')

        private

        # Instantiates the command notifier from the config, using the given options.
        # @param notifier_options [Hash] the options to pass to the command notifier
        # @param custom_batch_id [String] Custom batch ID
        # @param inline [Boolean] whether to process the commands inline
        # @return [void]
        def setup(notifier_options, custom_batch_id, inline = false)
          @command_notifiers = [] if inline

          @command_notifiers ||= Yes::Core.configuration.command_notifier_classes&.map do |notifier_class|
            notifier_class.new(notifier_options)
          end || []
          @custom_batch_id = custom_batch_id
        end

        # Runs the given commands through their respective aggregates.
        # @param commands [Array<Command>] the commands to run
        # @return [Array<Response>] responses from the performed commands
        def run_commands(commands, _inline = false)
          commands.map do |cmd|
            cmd_response = run_command(cmd)
            command_notifiers.each { _1.notify_command_response(cmd_response) }
            cmd_response
          end
        end

        # Executes a single command on its aggregate
        # @param cmd [Command, Yes::Core::Commands::CommandGroup] the command to execute
        # @return [Response, Yes::Core::Commands::CommandGroupResponse] response from executing the command
        def run_command(cmd)
          command_helper = Yes::Core::Commands::Helper.new(cmd)
          draft = draft?(cmd)
          aggregate = aggregate_class(cmd).new(cmd.aggregate_id, draft:)
          I18n.with_locale(command_helper.command_locale) do
            # CommandGroup exposes a flat `payload` (input minus reserved keys) which is
            # what the aggregate's group method expects; a regular Command's `to_h` is
            # already the flat attribute hash.
            payload = cmd.is_a?(Yes::Core::Commands::CommandGroup) ? cmd.payload : cmd.to_h
            aggregate.public_send(command_helper.command_name, payload, guards: !draft)
          end
        end

        def draft?(cmd)
          cmd.metadata&.dig(:draft) || cmd.metadata&.dig(:edit_template_command)
        end

        # Re-instantiates `cmd` with the given reserved keys merged in.
        # For regular {Yes::Core::Command} instances `cmd.to_h` is already the
        # flat attribute hash, so the round-trip is lossless. For
        # {Yes::Core::Commands::CommandGroup} instances `cmd.to_h` returns the
        # NESTED per-context/per-subject form, but `cmd.payload` is the FLAT
        # input form expected by the aggregate's group method; we round-trip
        # through `payload` to keep `payload` flat after re-instantiation.
        #
        # @param cmd [Yes::Core::Command, Yes::Core::Commands::CommandGroup]
        # @param origin [String, nil]
        # @param batch_id [String, nil]
        # @return [Yes::Core::Command, Yes::Core::Commands::CommandGroup]
        def reinstantiate_with_reserved_keys(cmd, origin:, batch_id:)
          if cmd.is_a?(Yes::Core::Commands::CommandGroup)
            cmd.class.new(
              cmd.payload.merge(
                origin:, batch_id:,
                command_id: cmd.command_id,
                metadata: cmd.metadata,
                transaction: cmd.transaction
              ).compact
            )
          else
            cmd.class.new(cmd.to_h.merge(origin:, batch_id:))
          end
        end

        # Determines the aggregate class for a given command
        # @param cmd [Command] The command to find the aggregate class for
        # @return [Class] The aggregate class that handles this command
        def aggregate_class(cmd)
          Yes::Core::Commands::Helper.new(cmd).aggregate_class
        end

        # Checks if a guard evaluator exists for the given command
        # @param cmd [Command] The command to check
        # @return [Boolean] true if a guard evaluator exists
        # @raise [UnregisteredCommand] if no guard evaluator is found for the command
        def guard_evaluator_exists?(cmd)
          command_helper = Yes::Core::Commands::Helper.new(cmd)

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
end
