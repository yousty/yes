# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Base class for evaluating guards on command attributes
      class GuardEvaluator
        class TransitionError < Yes::Core::Error; end
        class InvalidTransition < TransitionError; end
        class NoChangeTransition < TransitionError; end

        class << self
          # @return [Hash<Symbol, Proc>] Hash of registered guards with names as keys and blocks as values
          def guards
            @guards ||= {}
          end

          # Defines a new guard with a name and evaluation block
          #
          # @param name [Symbol] Name of the guard
          # @param error_extra [Proc] The extra information to be added to the error message payload
          # @yield Block to evaluate the guard condition
          # @yieldreturn [Boolean] True if the guard passes, false otherwise
          # @return [void]
          def guard(name, error_extra: nil, &block)
            guards[name] = { block:, error_extra: }
          end
        end

        # @param payload [Hash] The command payload
        # @param metadata [Hash] The command metadata
        # @param aggregate [Yes::Core::Aggregate] The aggregate instance
        # @param command_name [Symbol] The command name
        def initialize(payload:, metadata:, aggregate:, command_name:)
          @raw_payload = payload
          @raw_metadata = metadata
          @aggregate = aggregate
          @aggregate_tracker = AggregateTracker.new
          @command_name = command_name
          @payload = PayloadProxy.new(
            raw_payload:,
            raw_metadata:,
            context: aggregate.class.context,
            aggregate_tracker:,
            parent_aggregates: aggregate.class.parent_aggregates
          )
        end

        # Evaluates all registered guards
        #
        # @return [void]
        # @raise [InvalidTransition] When a guard fails with an invalid transition
        # @raise [NoChangeTransition] When a guard fails with a no change transition
        def call
          self.class.guards.each do |name, guard_data|
            evaluate_guard(name, error_extra: guard_data[:error_extra], block: guard_data[:block])
          end
        end

        # @return [Array<Hash>] List of accessed external aggregates with their revisions
        delegate :accessed_external_aggregates, to: :aggregate_tracker

        private

        attr_reader :raw_payload, :raw_metadata, :payload, :aggregate, :aggregate_tracker, :command_name

        # Evaluates a single guard and raises appropriate error if it fails
        #
        # @param name [Symbol] The name of the guard
        # @param error_extra [Proc] The extra information to be added to the error message payload
        # @param block [Proc] The guard block to evaluate
        # @return [void]
        # @raise [InvalidTransition] When the guard fails with an invalid transition
        # @raise [NoChangeTransition] When the guard fails with a no change transition
        def evaluate_guard(name, block:, error_extra: nil)
          result = evaluate_with_locale(&block)
          return if result

          extra =
            if error_extra.present?
              if error_extra.respond_to?(:call)
                evaluate_with_locale(&error_extra)
              else
                error_extra
              end
            else
              {}
            end

          error_class = name == :no_change ? NoChangeTransition : InvalidTransition
          raise error_class.new(error_message(name), extra: extra)
        end

        def value_changed?(val1, val2)
          return val1 != val2 unless val1.is_a?(Hash) && val2.is_a?(Hash)

          val1.with_indifferent_access != val2.with_indifferent_access
        end

        # Looks up the error message for a guard from I18n translations
        #
        # @param guard_name [Symbol] The name of the guard
        # @return [String] The error message
        def error_message(guard_name)
          context_name = aggregate.class.context
          aggregate_name = aggregate.class.aggregate

          Yes::Core::ErrorMessages.guard_error(context_name, aggregate_name, command_name.to_s, guard_name)
        end

        # Handles method missing to delegate attribute calls to the current aggregate
        #
        # @param method_name [Symbol] The method name being called
        # @yield Optional block passed to the method (unused)
        # @yieldreturn [void]
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
            revision: -> { instance.reload.revision },
            context: aggregate.class.context
          )
        end

        # Evaluates a block with the locale from payload if present
        #
        # @yield Block to be evaluated
        # @return [Object] Result of block evaluation
        def evaluate_with_locale(&block)
          if raw_payload[:locale].present?
            I18n.with_locale(raw_payload[:locale]) { instance_eval(&block) }
          else
            instance_eval(&block)
          end
        end
      end
    end
  end
end
