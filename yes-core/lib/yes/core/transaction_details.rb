# frozen_string_literal: true

require 'securerandom'

module Yes
  module Core
    # @api private
    module TransactionDetailsTypes
      # OpenTelemetry context data for distributed tracing
      class OtlContexts < Dry::Struct
        transform_keys(&:to_sym)

        context_schema = Types::Hash.schema(
          traceparent?: Types::String,
          service?: Types::String
        ).with_key_transform(&:to_sym)

        timestamps_schema = Types::Hash.schema(
          command_request_started_at_ms?: Types::Integer,
          command_handling_started_at_ms?: Types::Integer
        ).with_key_transform(&:to_sym)

        attribute?(:root, context_schema.default { {} })
        attribute?(:publisher, context_schema.default { {} })
        attribute?(:timestamps, timestamps_schema.default { {} })

        # @param context [Hash]
        def publisher=(context)
          @attributes = attributes.merge(publisher: context)
        end

        # @param context [Hash]
        def root=(context)
          @attributes = attributes.merge(root: context)
        end
      end
    end

    # Value object representing a command transaction's context.
    #
    # Carries correlation/causation IDs for event sourcing traceability,
    # caller identity, and OpenTelemetry trace context.
    #
    # @example
    #   TransactionDetails.new(
    #     name: "CreateUser",
    #     correlation_id: SecureRandom.uuid,
    #     caller_id: current_user.id,
    #     caller_type: 'User'
    #   )
    class TransactionDetails < Dry::Struct
      schema schema.strict
      transform_keys(&:to_sym)

      attribute?(:name, Types::String.optional.default(nil))
      attribute(:correlation_id, Types::UUID.default { SecureRandom.uuid })
      attribute?(:causation_id, Types::UUID.optional.default(nil))
      attribute?(:caller_id, Types::UUID.optional.default(nil))
      attribute?(:caller_type, Types::String.optional.default(nil))
      attribute?(:otl_contexts, TransactionDetailsTypes::OtlContexts)

      # Returns metadata formatted for the event store.
      #
      # @return [Hash] with :$correlationId and :$causationId keys
      def for_eventstore_metadata
        to_h.slice(:correlation_id, :causation_id, :otl_contexts).tap do |h|
          h[:$correlationId] = h.delete(:correlation_id)
          h[:$causationId] = h.delete(:causation_id)
        end
      end

      # @return [Hash] compact hash representation
      def to_h
        super.compact
      end

      # Creates TransactionDetails from an existing event.
      #
      # @param event [Yes::Core::Event] the source event
      # @return [TransactionDetails]
      def self.from_event(event)
        new(
          correlation_id: event.metadata['$correlationId'].presence || SecureRandom.uuid,
          causation_id: event.id,
          otl_contexts: event.metadata['otl_contexts']
        )
      end
    end
  end
end
