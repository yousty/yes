# frozen_string_literal: true

module Yes
  module Core
    # Extracts encryption metadata from a command/event's encryption schema.
    #
    # @example
    #   metadata = EncryptionMetadata.new(data: event.data, schema: event.class.encryption_schema)
    #   metadata.call # => { key: 'user-123', attributes: [:email, :phone] }
    class EncryptionMetadata
      # @return [Hash] the encryption metadata (key, attributes) or empty hash
      def call
        return {} unless schema

        {
          key: schema[:key].call(data),
          attributes: schema[:attributes].map(&:to_sym)
        }
      end

      private

      attr_reader :data, :schema

      # @param data [Hash] the event data
      # @param schema [Hash, nil] the encryption schema with :key (callable) and :attributes (array)
      def initialize(data:, schema:)
        @data = data.transform_keys(&:to_sym)
        @schema = schema
      end
    end
  end
end
