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

        delegate :events, :remove_read_model, :read_model, :revision_column, to: :aggregate

        # @param aggregate [Yes::Core::Aggregate] The aggregate whose read model needs rebuilding
        def initialize(aggregate)
          @aggregate = aggregate
        end

        # Rebuilds the read model by processing all events
        # @param remove [Boolean] Whether to remove the read model before rebuilding
        # @return [void]
        def call(remove: true)
          if remove
            remove_read_model 
          else
            read_model.update(revision_column => -1)
          end
          events.each { |events_page| events_page.each { |event| process_event(event) } }
        end

        private

        # @param event [Object] The event to process for read model rebuilding
        # @return [void]
        def process_event(event)
          CommandHandling::ReadModelUpdater.new(aggregate).call(event, nil, resolve_payload: true)
        end
      end
    end
  end
end
