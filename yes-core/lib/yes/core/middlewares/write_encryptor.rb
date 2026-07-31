# frozen_string_literal: true

module Yes
  module Core
    module Middlewares
      # Encrypts on the way in exactly like {Encryptor}, but does not decrypt on the way out.
      #
      # pg_eventstore 3.0 runs every registered middleware's #deserialize on the events returned by
      # #append_to_stream, not only on the ones returned by reads. Nothing on the write path reads `data` off
      # that returned event, so decrypting it costs two uncached HTTP calls to the encryptor service (a key
      # lookup and a decrypt) per encrypted event, for a payload that is immediately discarded.
      #
      # #serialize is inherited rather than reimplemented on purpose: encryption at rest must never differ
      # between the read and the write variant.
      #
      # Registered alongside {Encryptor} by {Middlewares.register_encryptor} and selected by
      # {Middlewares.for_write}. The read path keeps using {Encryptor}, unchanged.
      #
      # @example
      #   PgEventstore.client.append_to_stream(stream, event, middlewares: Yes::Core::Middlewares.for_write)
      class WriteEncryptor < Encryptor
        # Deliberately does nothing: the caller does not read the returned event's data.
        #
        # Returns the event rather than nil. pg_eventstore itself ignores the return value, but middlewares
        # are also invoked directly in places that use it.
        #
        # @param event [PgEventstore::Event]
        # @return [PgEventstore::Event]
        def deserialize(event)
          event
        end
      end
    end
  end
end
