# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Updates read models with revision guard to ensure consistency
      # Handles state updater instantiation and execution within a revision-protected context
      #
      # @example
      #   updater = ReadModelUpdater.new(aggregate)
      #   updater.call(event, command_payload, :approve_documents)
      #
      class ReadModelUpdater
        include Yousty::Eventsourcing::OpenTelemetry::Trackable
        # Initializes a new ReadModelUpdater
        #
        # @param aggregate [Yes::Core::Aggregate] The aggregate instance to update read model for
        def initialize(aggregate)
          @aggregate = aggregate
          @read_model = aggregate.read_model if aggregate.class.read_model_enabled?
          @command_utilities = aggregate.send(:command_utilities)
          @revision_column = aggregate.send(:revision_column) if aggregate.class.read_model_enabled?
        end

        # Updates the read model with revision guard protection
        #
        # @param event [Yousty::Eventsourcing::Event] The event that was published
        # @param command_payload [Hash] The command payload
        # @param command_name [Symbol, String] The command name (optional, will be derived from event if not provided)
        # @return [void]
        def call(event, command_payload, command_name = nil)
          return unless aggregate.class.read_model_enabled?

          command_name ||= command_utilities.command_name_from_event(event, aggregate.class)
          locale = command_payload[:locale]

          state_updater_class = command_utilities.fetch_state_updater_class(command_name)

          ReadModelRevisionGuard.call(
            read_model,
            event.stream_revision,
            revision_column: revision_column
          ) do
            state_changes = state_updater_class.new(
              payload: command_payload.except(*Yousty::Eventsourcing::Command::RESERVED_KEYS),
              aggregate:,
              event:
            ).call

            aggregate.update_read_model(
              state_changes.merge(
                revision_column => event.stream_revision,
                locale:,
                pending_update_since: nil
              )
            )
          end
        rescue ReadModelRevisionGuard::RevisionAlreadyAppliedError => e
          Rails.logger.warn("Read model revision already applied: #{e.message}")
        end
        
        otl_trackable(
          :call,
          Yousty::Eventsourcing::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Update read model', span_kind: :producer, track_sql: true)
        )

        private

        attr_reader :aggregate, :read_model, :command_utilities, :revision_column
      end
    end
  end
end