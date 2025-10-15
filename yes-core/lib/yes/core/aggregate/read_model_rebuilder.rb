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

        delegate :events, :remove_read_model, to: :aggregate

        # @param aggregate [Yes::Core::Aggregate] The aggregate whose read model needs rebuilding
        def initialize(aggregate)
          @aggregate = aggregate
        end

        # Rebuilds the read model by processing all events
        # @param remove [Boolean] Whether to remove the read model before rebuilding
        # @return [void]
        def call(remove: true)
          remove_read_model if remove
          events.each { |events_page| events_page.each { |event| process_event(event) } }
        end

        private

        # @param event [Object] The event to process for read model rebuilding
        # @return [void]
        def process_event(event)
          CommandHandling::ReadModelUpdater.new(aggregate).call(event, event.data)
        end
      end
    end
  end
end
