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
        def call(event, command_payload, command_name = nil, resolve_payload: false)
          return unless aggregate.class.read_model_enabled?

          begin
            command_name ||= command_utilities.command_name_from_event(event, aggregate.class)
          rescue Yes::Core::Utils::CommandUtils::CommandNotFoundError => e
            Rails.logger.warn("Command not found for event #{event.type}: #{e.message}")

            # update revision only in case event is unknown to aggregate
            return update_revision(event.stream_revision)
          end

          payload = command_payload ? command_payload : payload_from_event(event, resolve_payload)
          
          locale = payload[:locale]

          state_updater_class = command_utilities.fetch_state_updater_class(command_name)

          ReadModelRevisionGuard.call(
            read_model,
            event.stream_revision,
            revision_column:
          ) do
            state_changes = state_updater_class.new(
              payload: payload.except(*Yousty::Eventsourcing::Command::RESERVED_KEYS),
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

        def update_revision(revision)
          aggregate.update_read_model(revision_column => revision)
        end

        def payload_from_event(event, resolve_payload)
          return event.data if !resolve_payload
          return event.data unless event.data.values.any? { _1.start_with?(Yes::Core::Event::PAYLOAD_STORE_VALUE_PREFIX) }

          Yousty::Eventsourcing::PayloadStore::Lookup.new.call(event).each do |key, value|
            event.data[key.to_s] = value
          end

          event.data
        end  
      end
    end
  end
end