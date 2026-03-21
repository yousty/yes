# frozen_string_literal: true

module Yes
  module Core
    # Resolves PgEventstore event types back into their proper class.
    # When configured as the event_class_resolver in PgEventstore, events
    # deserialized from the store will be instances of their registered class
    # (e.g., `Test::UserCreated < Yes::Core::Event`) instead of raw `PgEventstore::Event`.
    class EventClassResolver
      # Proxy that skips schema validation when deserializing events from the store,
      # since stored events are already validated.
      class SkipValidationProxy < BasicObject
        # @param klass [Class] the event class to proxy
        def initialize(klass)
          @klass = klass
        end

        # @param attrs [Hash] event attributes from the store
        # @return [Yes::Core::Event] the event instance with validation skipped
        def new(**attrs)
          @klass.new(**attrs.merge(skip_validation: true))
        end
      end

      # Resolves an event type string to its class.
      #
      # @param event_type [String] the event type (e.g., "Test::UserCreated")
      # @return [#new] the event class or a proxy that skips validation
      def call(event_type)
        SkipValidationProxy.new(Object.const_get(event_type))
      rescue NameError, TypeError
        PgEventstore.logger&.debug(<<~TEXT.strip)
          Unable to resolve class by `#{event_type}' event type. \
          Picking #{Event} event class to instantiate the event.
        TEXT
        Event
      end
    end
  end
end
