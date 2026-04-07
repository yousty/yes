# frozen_string_literal: true

module Yes
  module Core
    module Middlewares
      # PgEventstore middleware that adds a created_at timestamp to event metadata
      # on serialization and parses it back on deserialization.
      class Timestamp
        include PgEventstore::Middleware

        # @param event [PgEventstore::Event]
        # @return [PgEventstore::Event]
        def serialize(event)
          event.metadata[:created_at] ||= Time.now.utc
          event
        end

        # @param event [PgEventstore::Event]
        # @return [PgEventstore::Event]
        def deserialize(event)
          return event unless event.metadata.key?('created_at')

          event.metadata['created_at'] = Time.zone.parse(event.metadata['created_at'])
          event
        end
      end
    end
  end
end
