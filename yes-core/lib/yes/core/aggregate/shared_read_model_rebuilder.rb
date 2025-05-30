# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      # Handles rebuilding of read models that are shared by multiple aggregates
      #
      # @example Using the shared rebuilder
      #   rebuilder = SharedReadModelRebuilder.new(SharedUserReadModel)
      #   rebuilder.call
      class SharedReadModelRebuilder
        # Value object to hold event data with aggregate information
        EventWithAggregate = Struct.new(:event, :aggregate, keyword_init: true) do
          # @return [Time] The creation timestamp of the event
          delegate :created_at, to: :event
        end

        # @param read_model_class [Class] The Active Record read model class to rebuild
        # @param ids [Array<String>] Array of IDs to rebuild
        # @example
        #   rebuilder = SharedReadModelRebuilder.new(SharedUserProfile, ['user-1', 'user-2'])
        #   rebuilder.call
        def initialize(read_model_class, ids)
          @read_model_class = read_model_class
          @ids = ids
          @aggregate_types = find_aggregates_using_read_model
        end

        # Rebuilds the shared read model by processing all events from all aggregates
        # @return [void]
        def call
          ids.each do |id|
            rebuild_read_model_for_id(id)
          end
        end

        private

        # @return [Class] The read model class being rebuilt
        # @return [Array<String>] The IDs to rebuild
        # @return [Array<Array<String>>] The aggregate types that use this read model
        attr_reader :read_model_class, :ids, :aggregate_types

        # Finds all aggregates that use the given read model class
        # @return [Array<Array<String>>] Array of [context_name, aggregate_name] pairs
        def find_aggregates_using_read_model
          aggregates = []

          Yes::Core.configuration.list_all_registered_classes.each do |key, classes|
            next unless classes[:read_model] == read_model_class

            context_name, aggregate_name = key
            aggregates << [context_name, aggregate_name]
          end

          aggregates
        end

        # Rebuilds the read model for a single ID
        # @param id [String] The ID to rebuild
        # @return [void]
        def rebuild_read_model_for_id(id)
          remove_read_model_for_id(id)

          aggregates = instantiate_aggregates_for_id(id)
          events_with_aggregates = collect_events_from_aggregates(aggregates)
          sorted_events = events_with_aggregates.sort_by(&:created_at)

          sorted_events.each do |event_with_aggregate|
            process_event_with_aggregate(event_with_aggregate)
          end
        end

        # Removes the read model instance for a specific ID
        # @param id [String] The ID to remove
        # @return [void]
        def remove_read_model_for_id(id)
          read_model_class.find_by(id: id)&.destroy
        end

        # Instantiates all aggregate instances for a given ID
        # @param id [String] The ID to instantiate aggregates for
        # @return [Array<Aggregate>] The instantiated aggregates
        def instantiate_aggregates_for_id(id)
          aggregate_types.map do |context_name, aggregate_name|
            aggregate_class = build_aggregate_class(context_name, aggregate_name)
            aggregate_class.new(id)
          end
        end

        # Collects all events from the given aggregates
        # @param aggregates [Array<Aggregate>] The aggregates to collect events from
        # @return [Array<EventWithAggregate>] All events with their aggregate references
        def collect_events_from_aggregates(aggregates)
          events_with_aggregates = []

          aggregates.each do |aggregate|
            aggregate.events.each do |events_page|
              events_page.each do |event|
                events_with_aggregates << EventWithAggregate.new(
                  event: event,
                  aggregate: aggregate
                )
              end
            end
          end

          events_with_aggregates
        end

        # Builds the aggregate class from context and aggregate names
        # @param context_name [String] The context name
        # @param aggregate_name [String] The aggregate name
        # @return [Class] The aggregate class
        def build_aggregate_class(context_name, aggregate_name)
          "#{context_name}::#{aggregate_name}::Aggregate".constantize
        end

        # Processes a single event with its aggregate information
        # @param event_with_aggregate [EventWithAggregate] The event with aggregate data
        # @return [void]
        def process_event_with_aggregate(event_with_aggregate)
          aggregate = event_with_aggregate.aggregate
          command_utilities = aggregate.send(:command_utilities)

          command_name = command_utilities.command_name_from_event(
            event_with_aggregate.event,
            aggregate.class
          )

          payload = event_with_aggregate.event.data
          locale = payload.delete(:locale)

          state_updater = command_utilities.fetch_state_updater_class(command_name).new(
            payload: payload,
            aggregate: aggregate
          )

          aggregate.update_read_model(
            state_updater.call.merge(
              revision: event_with_aggregate.event.stream_revision,
              locale: locale
            )
          )
        end
      end
    end
  end
end
