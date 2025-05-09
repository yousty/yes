# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      # Handles rebuilding of read models for aggregates
      #
      # @example Using the rebuilder
      #   rebuilder = ReadModelRebuilder.new(aggregate)
      #   rebuilder.call
      class ReadModelRebuilder
        attr_reader :aggregate
        private :aggregate

        delegate :events, :read_model, :update_read_model, to: :aggregate

        # @param aggregate [Yes::Core::Aggregate] The aggregate whose read model needs rebuilding
        def initialize(aggregate)
          @aggregate = aggregate
        end

        # Rebuilds the read model by processing all events
        # @return [void]
        def call
          aggregate.remove_read_model
          events.each { |events_page| events_page.each { |event| process_event(event) } }
        end

        private

        # @param event [Object] The event to process for read model rebuilding
        # @return [void]
        def process_event(event)
          command_name = command_utilities.command_name_from_event(event, aggregate.class)
          payload = event.data
          locale = payload.delete(:locale)
          state_updater = command_utilities.fetch_state_updater_class(command_name).new(payload:, aggregate:)

          update_read_model(
            state_updater.call.merge(
              revision: event.stream_revision,
              locale: locale
            )
          )
        end

        # @return [Yes::Core::CommandUtilities] The command utilities for the aggregate
        def command_utilities
          @command_utilities ||= aggregate.send(:command_utilities)
        end
      end
    end
  end
end
