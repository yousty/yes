# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Base class for handling custom state updates on command attributes
      class StateUpdater
        class << self
          # @return [Hash] The update state block
          attr_reader :update_state_block
          attr_reader :updated_attributes

          # Defines the update state block and analyzes it for attribute updates
          #
          # @yield Block to evaluate for state updates
          # @yieldreturn [void]
          # @return [void]
          def update_state(&block)
            @update_state_block = block
            @updated_attributes = []

            # Create a temporary instance to analyze the block
            analyzer = BlockAnalyzer.new
            analyzer.instance_eval(&block)
            @updated_attributes = analyzer.updated_attributes
          end
        end

        # Helper class to analyze the update_state block at definition time
        class BlockAnalyzer
          attr_reader :updated_attributes

          def initialize
            @updated_attributes = []
          end

          # @param method_name [Symbol] The method being called
          # @param args [Array] Method arguments (unused)
          # @yield Optional block to evaluate for attribute value
          # @yieldreturn [void]
          # @return [void]
          def method_missing(method_name, *args, &block)
            @updated_attributes << method_name if block
          end

          def respond_to_missing?(*, **)
            true
          end
        end

        # @param payload [Hash] The command payload
        # @param aggregate [Yes::Core::Aggregate] The aggregate instance
        def initialize(payload:, aggregate:)
          @raw_payload = payload
          @aggregate = aggregate
          @payload = PayloadProxy.new(
            raw_payload:,
            context: aggregate.class.context
          )
        end

        # Evaluates the update state block and returns the updated attributes
        # If no block is defined, returns the payload attributes except aggregate_id
        #
        # @return [Hash] The updated attributes
        def call
          if self.class.update_state_block
            @updates = {}
            instance_eval(&self.class.update_state_block)
            @updates
          else
            raw_payload.except(:"#{aggregate.class.aggregate.underscore}_id")
          end
        end

        private

        attr_reader :raw_payload, :payload, :aggregate

        # Handles method missing to delegate attribute calls to the current aggregate
        #
        # @param method_name [Symbol] The method name being called
        # @yield Optional block to evaluate for the attribute value
        # @yieldreturn [Object] The value to set for the attribute
        # @return [Object] The result of calling the method on the current aggregate
        def method_missing(method_name, *, &block)
          if block
            @updates[method_name] = instance_eval(&block)
          elsif aggregate.respond_to?(method_name)
            aggregate.public_send(method_name, *, &block)
          else
            super
          end
        end

        # Checks if method is defined on the current aggregate
        #
        # @param method_name [Symbol] The method name to check
        # @param include_private [Boolean] Whether to include private methods
        # @return [Boolean] True if method exists
        def respond_to_missing?(method_name, include_private = false)
          aggregate.respond_to?(method_name, include_private) || super
        end
      end
    end
  end
end
