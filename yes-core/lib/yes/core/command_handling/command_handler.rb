# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Handles the complete command execution flow for aggregates
      # This class orchestrates command preparation, execution, and read model updates
      #
      # @example
      #   handler = CommandHandler.new(aggregate)
      #   response = handler.call(:approve_documents, { document_ids: '123', another: 'value' })
      #
      class CommandHandler
        # Initializes a new CommandHandler
        #
        # @param aggregate [Yes::Core::Aggregate] The aggregate instance to handle commands for
        def initialize(aggregate)
          @aggregate = aggregate
          @command_utilities = aggregate.send(:command_utilities)
          @read_model = aggregate.read_model
        end

        # Executes a command and updates the aggregate state
        #
        # @param command_name [Symbol] The name of the command to execute
        # @param payload [Hash] The command payload
        # @param guards [Boolean] Whether to evaluate guards (default: true)
        # @return [Yousty::Eventsourcing::Stateless::CommandResponse] The command response
        def call(command_name, payload, guards: true)
          prepared_payload = prepare_payload(command_name, payload)
          cmd = command_utilities.build_command(command_name, prepared_payload)
          
          guard_evaluator_class = command_utilities.fetch_guard_evaluator_class(command_name)

          ReadModelRecoveryService.check_and_recover_with_retries(read_model, aggregate:)

          response = CommandExecutor.new(aggregate).
            call(cmd, command_name, guard_evaluator_class, skip_guards: !guards)

          ReadModelUpdater.new(aggregate).call(response.event, prepared_payload, command_name) if response.success?

          response
        end

        private

        attr_reader :aggregate, :command_utilities, :read_model

        # Prepares the command payload
        #
        # @param command_name [Symbol] The command name
        # @param payload [Hash] The raw payload
        # @return [Hash] The prepared payload
        def prepare_payload(command_name, payload)
          prepared = command_utilities.prepare_command_payload(
            command_name, 
            payload.clone, 
            aggregate.class
          )
          prepared = command_utilities.prepare_assign_command_payload(command_name, prepared)
          
          add_draft_metadata(prepared) if aggregate.draft?
          add_otl_metadata(prepared)
          
          prepared
        end

        # Adds draft metadata to payload if aggregate is draft
        #
        # @param payload [Hash] The payload to modify
        # @return [void]
        def add_draft_metadata(payload)
          payload[:metadata] ||= {}
          payload[:metadata][:draft] = true
        end

        def add_otl_metadata(payload)
          return if payload.dig(:metadata, :otl_contexts).blank?

          payload[:metadata][:otl_contexts][:timestamps][:command_handling_started_at_ms] = (Time.now.utc.to_f * 1000).to_i 
        end
      end
    end
  end
end