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
        include Yousty::Eventsourcing::OpenTelemetry::Trackable
        # Initializes a new CommandHandler
        #
        # @param aggregate [Yes::Core::Aggregate] The aggregate instance to handle commands for
        def initialize(aggregate)
          @aggregate = aggregate
          @command_utilities = aggregate.send(:command_utilities)
          @read_model = aggregate.read_model if aggregate.class.read_model_enabled?
        end

        # Executes a command and updates the aggregate state
        #
        # @param command_name [Symbol] The name of the command to execute
        # @param payload [Hash] The command payload
        # @param guards [Boolean] Whether to evaluate guards (default: true)
        # @param metadata [Hash] Optional custom metadata to add to the event
        # @return [Yousty::Eventsourcing::Stateless::CommandResponse] The command response
        def call(command_name, payload, guards: true, metadata: nil)
          prepared_payload = prepare_payload(command_name, payload, metadata)
          cmd = command_utilities.build_command(command_name, prepared_payload)

          guard_evaluator_class = command_utilities.fetch_guard_evaluator_class(command_name)

          if aggregate.class.read_model_enabled?
            ReadModelRecoveryService.check_and_recover_with_retries(read_model, aggregate:)
          end

          response = CommandExecutor.new(aggregate).
            call(cmd, command_name, guard_evaluator_class, skip_guards: !guards)

          if aggregate.class.read_model_enabled? && response.success?
            ReadModelUpdater.new(aggregate).call(response.event, prepared_payload, command_name)
          end

          response
        end
        otl_trackable :call,
                      Yousty::Eventsourcing::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Execute command')

        private

        attr_reader :aggregate, :command_utilities, :read_model

        # Prepares the command payload
        #
        # @param command_name [Symbol] The command name
        # @param payload [Hash] The raw payload
        # @param custom_metadata [Hash] Optional custom metadata to merge
        # @return [Hash] The prepared payload
        def prepare_payload(command_name, payload, custom_metadata = nil)
          prepared = command_utilities.prepare_default_payload(
            command_name,
            payload,
            aggregate.class
          )
          prepared = command_utilities.prepare_command_payload(
            command_name,
            prepared,
            aggregate.class
          )
          prepared = command_utilities.prepare_assign_command_payload(
            command_name,
            prepared
          )

          add_custom_metadata(prepared, custom_metadata) if custom_metadata.present?
          add_draft_metadata(prepared) if aggregate.draft?
          add_otl_metadata(prepared)

          prepared
        end

        # Adds custom metadata to payload
        #
        # @param payload [Hash] The payload to modify
        # @param custom_metadata [Hash] The custom metadata to merge
        # @return [void]
        def add_custom_metadata(payload, custom_metadata)
          payload[:metadata] ||= {}
          payload[:metadata].merge!(custom_metadata)
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
