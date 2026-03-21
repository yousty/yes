# frozen_string_literal: true

module Yes
  module Core
    module TestSupport
      # Helpers for working with PgEventstore events in tests.
      module EventHelpers
        # @param stream [PgEventstore::Stream]
        # @param event [Yes::Core::Event]
        # @return [Yes::Core::Event]
        def append_and_reload_event(stream, event)
          PgEventstore.client.append_to_stream(stream, event)
          PgEventstore.client.read(stream, options: { max_count: 1, direction: :desc }).first
        end

        # Reads eventstore and returns events from the stream or an empty array if stream does not exist
        # @param stream [PgEventstore::Stream]
        # @return [Array<Yes::Core::Event>]
        def safe_read(stream)
          PgEventstore.client.read(stream)
        rescue PgEventstore::StreamNotFoundError
          []
        end
      end
    end
  end
end
