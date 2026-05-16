# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # High-level orchestrator for executing a {Yes::Core::Commands::CommandGroup}.
      #
      # Mirrors {CommandHandler} but produces a
      # {Yes::Core::Commands::CommandGroupResponse} carrying the array of
      # published events. Group-level guards run; sub-command guards are
      # bypassed (the executor publishes each sub-command's event directly).
      #
      # @example
      #   handler = CommandGroupHandler.new(aggregate)
      #   response = handler.call(:create_apprenticeship, {
      #     company_id:, user_id:, name:, description:
      #   })
      class CommandGroupHandler
        include Yes::Core::OpenTelemetry::Trackable

        # @param aggregate [Yes::Core::Aggregate]
        def initialize(aggregate)
          @aggregate = aggregate
          @command_utilities = aggregate.send(:command_utilities)
          @read_model = aggregate.read_model if aggregate.class.read_model_enabled?
        end

        # Executes a command group and updates the aggregate's read model.
        #
        # @param group_name [Symbol] the command group name
        # @param payload [Hash] flat / partially-nested input payload
        # @param guards [Boolean] whether to evaluate the group's guards
        # @param metadata [Hash, nil] optional metadata to merge into each event
        # @return [Yes::Core::Commands::CommandGroupResponse]
        def call(group_name, payload, guards: true, metadata: nil)
          prepared = prepare_payload(payload, metadata)
          cmd = command_utilities.build_group_command(group_name, prepared)
          guard_evaluator_class = command_utilities.fetch_guard_evaluator_class_for_group(group_name)

          ReadModelRecoveryService.check_and_recover_with_retries(read_model, aggregate:) if aggregate.class.read_model_enabled?

          CommandGroupExecutor.new(aggregate).
            call(cmd, group_name, guard_evaluator_class, skip_guards: !guards)
        end
        otl_trackable :call,
                      Yes::Core::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Execute command group')

        private

        attr_reader :aggregate, :command_utilities, :read_model

        # Prepares the payload before constructing the group command.
        # Mirrors the metadata-injection logic in {CommandHandler#prepare_payload}.
        #
        # @param payload [Hash]
        # @param metadata [Hash, nil]
        # @return [Hash]
        def prepare_payload(payload, metadata)
          payload = payload.is_a?(Hash) ? payload.dup : {}

          add_console_origin(payload)
          add_draft_metadata(payload) if aggregate.draft?
          add_custom_metadata(payload, metadata)

          payload
        end

        def add_console_origin(payload)
          return if payload[:origin].present?

          console_origin = Utils::CallerUtils.console_origin
          payload[:origin] = console_origin if console_origin
        end

        def add_draft_metadata(payload)
          payload[:metadata] ||= {}
          payload[:metadata][:draft] = true
        end

        def add_custom_metadata(payload, metadata)
          return if metadata.blank?

          payload[:metadata] ||= {}
          payload[:metadata].merge!(metadata)
        end
      end
    end
  end
end
