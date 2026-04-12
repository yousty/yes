# frozen_string_literal: true

module Yes
  module Core
    module TestSupport
      # Helpers for working with PgEventstore events in tests.
      #
      # @example Include in RSpec
      #   RSpec.configure do |config|
      #     config.include Yes::Core::TestSupport::EventHelpers
      #   end
      module EventHelpers
        # Appends an event to a stream
        #
        # @param stream [PgEventstore::Stream]
        # @param event [Yes::Core::Event]
        # @return [void]
        def append_event(stream, event)
          PgEventstore.client.append_to_stream(stream, event)
        end

        # Appends an event to a stream and reloads it
        #
        # @param stream [PgEventstore::Stream]
        # @param event [Yes::Core::Event]
        # @return [Yes::Core::Event]
        def append_and_reload_event(stream, event)
          append_event(stream, event)
          PgEventstore.client.read(stream, options: { max_count: 1, direction: :desc }).first
        end

        # Reads eventstore and returns events from the stream or an empty array if stream does not exist
        #
        # @param stream [PgEventstore::Stream]
        # @return [Array<Yes::Core::Event>]
        def safe_read(stream)
          PgEventstore.client.read(stream)
        rescue PgEventstore::StreamNotFoundError
          []
        end

        alias read_events safe_read

        # Creates events from a block and appends them to the eventstore
        #
        # @yield block that returns an array of event attribute hashes
        # @yieldreturn [Array<Hash>] each hash should have :context, :aggregate, :event, :data keys
        # @return [void]
        #
        # @example
        #   given_events do
        #     [{ context: 'MyContext', aggregate: 'MyAggregate', event: 'Created', data: { id: '123' } }]
        #   end
        def given_events(&)
          events_data = yield
          events_data.each do |event_data|
            event = event_instance(event_data)
            stream = event_stream(event_data)
            append_event(stream, event)
          end
        end

        # Builds a Yes::Core::Event from a hash of event attributes
        #
        # @param event_attrs [Hash] event attributes with :context, :aggregate, :event, :data keys
        # @return [Yes::Core::Event]
        def event_instance(event_attrs)
          Yes::Core::Event.new(
            type: event_type(event_attrs),
            data: (event_attrs[:data] || {}).with_indifferent_access
          )
        end

        # Builds a PgEventstore::Stream from event attributes
        #
        # @param event_attrs [Hash] event attributes with :context, :aggregate, :data keys
        # @return [PgEventstore::Stream]
        def event_stream(event_attrs)
          return event_attrs[:stream] if event_attrs[:stream]

          PgEventstore::Stream.new(
            context: event_attrs[:context],
            stream_name: event_attrs[:aggregate],
            stream_id: event_attrs[:data].first.last
          )
        end

        # Constructs an event type string from event attributes
        #
        # @param event_attrs [Hash] event attributes with :context, :aggregate/:subject, :event keys
        # @return [String]
        def event_type(event_attrs)
          aggregate_or_subject = event_attrs[:aggregate] || event_attrs[:subject]
          "#{event_attrs[:context]}::#{aggregate_or_subject}#{event_attrs[:event]}"
        end
      end
    end
  end
end
