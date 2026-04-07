# frozen_string_literal: true

module Yes
  module Core
    # Base command class for all commands in the system.
    # Inherits from Dry::Struct for type-safe attribute definitions.
    class Command < Dry::Struct
      # Raised when a command fails validation
      class Invalid < Error; end

      RESERVED_KEYS = %i[transaction origin batch_id command_id metadata es_encrypted].freeze

      attribute? :transaction, Types.Instance(TransactionDetails).optional
      attribute? :origin, Types::String.optional
      attribute? :batch_id, Types::String.optional
      attribute? :metadata, Types::Hash.optional
      attribute(:command_id, Types::UUID.default { SecureRandom.uuid })

      # @param attributes [Hash] constructor parameters
      # @raise [Invalid] if the parameters are invalid
      def self.new(attributes)
        super
      rescue Dry::Struct::Error => e
        raise Invalid.new(extra: attributes), e
      end

      # Returns the command payload excluding reserved keys.
      #
      # @return [Hash] command payload as a hash
      def payload
        to_h.except(*RESERVED_KEYS)
      end
    end
  end
end
