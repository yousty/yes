# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Provides proxy access to command payload with dynamic aggregate resolution
      class PayloadProxy
        # @param raw_payload [Hash] The raw command payload
        # @param context [String] The context name
        # @param aggregate_tracker [AggregateTracker, nil] The tracker instance (optional)
        def initialize(raw_payload:, context:, aggregate_tracker: nil)
          @raw_payload = raw_payload
          @context = context
          @aggregate_tracker = aggregate_tracker
        end

        # Access payload values by key
        #
        # @param key [Symbol, String] The key to access
        # @return [Object] The value for the given key
        delegate :[], to: :@raw_payload

        private

        attr_reader :raw_payload, :context, :aggregate_tracker

        # Handles dynamic method calls to access payload values or resolve aggregates
        #
        # @param method_name [Symbol] The method being called
        # @param args [Array] Method arguments (unused)
        # @yield Optional block passed to the method (unused)
        # @yieldreturn [void]
        # @return [Object] The payload value or resolved aggregate
        def method_missing(method_name, *args, &)
          if raw_payload.key?(method_name)
            raw_payload[method_name]
          elsif raw_payload.key?(:"#{method_name}_id")
            resolve_aggregate(method_name)
          else
            super
          end
        end

        # Checks if method can be handled
        #
        # @param method_name [Symbol] The method to check
        # @param include_private [Boolean] Whether to include private methods
        # @return [Boolean] True if method can be handled
        def respond_to_missing?(method_name, include_private = false)
          raw_payload.key?(method_name) ||
            raw_payload.key?(:"#{method_name}_id") ||
            super
        end

        # Resolves an aggregate instance from its ID in the payload
        #
        # @param method_name [Symbol] The method name representing the aggregate
        # @return [Object] The resolved aggregate instance
        def resolve_aggregate(method_name)
          id = raw_payload[:"#{method_name}_id"]
          aggregate_class = "#{context}::#{method_name.to_s.camelize}::Aggregate".constantize
          instance = aggregate_class.new(id)

          aggregate_tracker&.track(
            attribute_name: method_name,
            id: instance.id,
            revision: -> { instance.reload.revision },
            context:
          )

          instance
        end
      end
    end
  end
end
