# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Provides proxy access to command payload with dynamic aggregate resolution
      class PayloadProxy
        # @param raw_payload [Hash] The raw command payload
        # @param raw_metadata [Hash, nil] The raw command metadata (optional)
        # @param context [String] The context name
        # @param aggregate_tracker [AggregateTracker, nil] The tracker instance (optional)
        def initialize(raw_payload:, context:, parent_aggregates:, raw_metadata: nil, aggregate_tracker: nil)
          @raw_payload = raw_payload
          @raw_metadata = raw_metadata
          @context = context
          @parent_aggregates = parent_aggregates
          @aggregate_tracker = aggregate_tracker
        end

        # Access payload values by key
        #
        # @param key [Symbol, String] The key to access
        # @return [Object] The value for the given key
        delegate :[], to: :@raw_payload

        # Access metadata through a proxy object
        #
        # @return [MetadataProxy] The metadata proxy object
        def metadata
          @metadata ||= MetadataProxy.new(@raw_metadata)
        end

        private

        attr_reader :raw_payload, :raw_metadata, :context, :parent_aggregates, :aggregate_tracker

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
          context = aggregate_context(method_name)
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

        def aggregate_context(aggregate_name)
          parent_aggregates.with_indifferent_access.dig(aggregate_name, :context) || context
        end
      end

      # Provides proxy access to command metadata
      class MetadataProxy
        # @param raw_metadata [Hash] The raw command metadata
        def initialize(raw_metadata)
          @raw_metadata = raw_metadata || {}
        end

        # Access metadata values by key (hash-style access)
        #
        # @param key [Symbol, String] The key to access
        # @return [Object] The value for the given key
        def [](key)
          raw_metadata[key]
        end

        # Set metadata values by key (hash-style assignment)
        #
        # @param key [Symbol, String] The key to set
        # @param value [Object] The value to set
        # @return [Object] The value that was set
        def []=(key, value)
          raw_metadata[key] = value
        end

        private

        attr_reader :raw_metadata

        # Handles dynamic method calls to access or set metadata values
        #
        # @param method_name [Symbol] The method being called
        # @param args [Array] Method arguments
        # @yield Optional block passed to the method (unused)
        # @yieldreturn [void]
        # @return [Object] The metadata value or the value being set
        def method_missing(method_name, *args, &)
          method_str = method_name.to_s

          # Handle setter methods (e.g., xyz=)
          if method_str.end_with?('=')
            key = method_str.chomp('=').to_sym
            raw_metadata[key] = args.first
          # Handle getter methods
          elsif args.empty?
            if raw_metadata.key?(method_name)
              raw_metadata[method_name]
            elsif raw_metadata.key?(method_str)
              raw_metadata[method_str]
            end
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
          method_str = method_name.to_s

          # Respond to setter methods
          return true if method_str.end_with?('=')

          # Respond to getter methods
          raw_metadata.key?(method_name) ||
            raw_metadata.key?(method_str) ||
            super
        end
      end
    end
  end
end
