# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Handles publishing events with revision checks
      class EventPublisher
        # Value object containing aggregate data needed for event publication
        AggregateEventPublicationData = Struct.new(:id, :context, :name, :revision, keyword_init: true) do
          def self.from_aggregate(aggregate)
            new(
              id: aggregate.id,
              context: aggregate.class.context,
              name: aggregate.class.name.split('::')[1],
              revision: aggregate.revision
            )
          end
        end

        # @param command [Object] The command instance
        # @param aggregate_data [AggregateEventPublicationData] The aggregate publication data
        # @param accessed_external_aggregates [Array<Hash>] List of accessed external aggregates with their revisions
        # @param event_name [String, nil] Optional explicit event name to use
        def initialize(command:, aggregate_data:, accessed_external_aggregates:, event_name: nil)
          @command = command
          @aggregate_data = aggregate_data
          @accessed_external_aggregates = accessed_external_aggregates
          @event_name = event_name
          @command_utilities = Utils::CommandUtils.new(
            context: aggregate_data.context,
            aggregate: aggregate_data.name,
            aggregate_id: aggregate_data.id
          )
        end

        # Publishes the event after verifying revisions
        #
        # @return [PgEventstore::Event] The published event
        # @raise [PgEventstore::WrongExpectedRevisionError] When revisions don't match
        def call
          verify_external_revisions!
          publish_event
        end

        private

        # @return [Object] The command instance
        attr_reader :command
        # @return [AggregateEventPublicationData] The aggregate publication data
        attr_reader :aggregate_data
        # @return [Array<Hash>] List of accessed external aggregates with their revisions
        attr_reader :accessed_external_aggregates
        # @return [String, nil] The explicit event name to use
        attr_reader :event_name
        # @return [CommandUtils] The command utilities instance
        attr_reader :command_utilities

        delegate :payload, :origin, :batch_id, :metadata, to: :command

        # Publishes the event to the event store
        #
        # @return [PgEventstore::Event] The published event
        def publish_event
          expected_revision = aggregate_data.revision == -1 ? :no_stream : aggregate_data.revision

          PgEventstore.client.append_to_stream(
            command_utilities.build_stream,
            event_with_metadata,
            options: { expected_revision: }
          )
        end

        # Verifies revisions of all accessed external aggregates
        #
        # @return [void]
        # @raise [PgEventstore::WrongExpectedRevisionError] When revisions don't match
        def verify_external_revisions!
          accessed_external_aggregates.each do |aggregate_data|
            stream = command_utilities.build_stream(
              context: aggregate_data[:context],
              name: aggregate_data[:name],
              id: aggregate_data[:id]
            )
            expected_revision = command_utilities.stream_revision(stream)
            normalized_revision = aggregate_data[:revision] == -1 ? :no_stream : aggregate_data[:revision]

            next if normalized_revision == expected_revision

            raise PgEventstore::WrongExpectedRevisionError.new(
              revision: aggregate_data[:revision],
              expected_revision:,
              stream:
            )
          end
        end

        # Builds an event with metadata from the command
        #
        # @return [PgEventstore::Event] The event with metadata
        def event_with_metadata
          command_utilities.build_event(
            command_name: command.class.name.split('::')[-2].underscore.to_sym,
            payload:,
            metadata: event_metadata
          )
        end

        # Builds the event metadata
        #
        # @return [Hash] The event metadata
        def event_metadata
          meta = {}
          meta['origin'] = origin if origin.present?
          meta['batch_id'] = batch_id if batch_id.present?
          meta.merge!(metadata) if metadata.present?
          meta
        end
      end
    end
  end
end
