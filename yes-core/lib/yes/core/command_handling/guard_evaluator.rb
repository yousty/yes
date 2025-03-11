# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Base class for evaluating guards on command attributes
      class GuardEvaluator
        class TransitionError < StandardError; end
        class InvalidTransition < TransitionError; end
        class NoChangeTransition < TransitionError; end

        class << self
          # @return [Array<Hash>] List of registered guards with their blocks and names
          def guards
            @guards ||= []
          end

          # Defines a new guard with a name and evaluation block
          #
          # @param name [Symbol] Name of the guard
          # @param block [Proc] Block to evaluate the guard condition
          # @return [void]
          def guard(name, &block)
            guards << { name:, block: }
          end
        end

        # @param payload [Hash] The command payload
        # @param aggregate [Yes::Core::Aggregate] The aggregate instance
        def initialize(payload:, aggregate:)
          @raw_payload = payload
          @aggregate = aggregate
          @aggregate_tracker = AggregateTracker.new
          @payload = PayloadProxy.new(
            raw_payload:,
            context: aggregate.class.context,
            aggregate_tracker:
          )
        end

        # Evaluates all registered guards
        #
        # @return [void]
        # @raise [InvalidTransition] When a guard fails with an invalid transition
        # @raise [NoChangeTransition] When a guard fails with a no change transition
        def call
          self.class.guards.each do |guard|
            evaluate_guard(guard)
          end
        end

        # @return [Array<Hash>] List of accessed external aggregates with their revisions
        delegate :accessed_external_aggregates, to: :aggregate_tracker

        private

        attr_reader :raw_payload, :payload, :aggregate, :aggregate_tracker

        # Evaluates a single guard and raises appropriate error if it fails
        #
        # @param guard [Hash] The guard to evaluate with its name and block
        # @return [void]
        # @raise [InvalidTransition] When the guard fails with an invalid transition
        # @raise [NoChangeTransition] When the guard fails with a no change transition
        def evaluate_guard(guard)
          result = instance_eval(&guard[:block])
          return if result

          error_class = guard[:name] == :no_change ? NoChangeTransition : InvalidTransition
          raise error_class, error_message(guard[:name])
        end

        # Looks up the error message for a guard from I18n translations
        #
        # @param guard_name [Symbol] The name of the guard
        # @return [String] The error message
        def error_message(guard_name)
          context_name = aggregate.class.context
          aggregate_name = aggregate.class.aggregate
          command_name = self.class.name.sub('::GuardEvaluator', '').demodulize

          Yes::Core::ErrorMessages.guard_error(context_name, aggregate_name, command_name, guard_name)
        end

        # Handles method missing to delegate attribute calls to the current aggregate
        #
        # @param method_name [Symbol] The method name being called
        # @param args [Array] Method arguments
        # @param block [Proc] Method block
        # @return [Object] The result of calling the method on the current aggregate
        def method_missing(method_name, *, &)
          if aggregate.respond_to?(method_name)
            result = aggregate.public_send(method_name, *, &)
            track_external_aggregate(method_name, result) if aggregate_attribute?(method_name)
            result
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

        # Checks if the given method is an aggregate attribute
        #
        # @param method_name [Symbol] The method name to check
        # @return [Boolean] True if the method is an aggregate attribute
        def aggregate_attribute?(method_name)
          aggregate.class.attributes[method_name] == :aggregate
        end

        # Tracks an external aggregate access
        #
        # @param attribute_name [Symbol] The attribute name
        # @param instance [Object] The aggregate instance
        # @return [void]
        def track_external_aggregate(attribute_name, instance)
          return unless instance

          aggregate_tracker.track(
            attribute_name: attribute_name.to_s.camelize,
            id: instance.id,
            revision: instance.revision,
            context: aggregate.class.context
          )
        end
      end
    end
  end
end
