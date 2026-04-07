# frozen_string_literal: true

module Yes
  module Core
    # Decrypts event data attributes using a key from the key repository.
    #
    # @example
    #   decryptor = DataDecryptor.new(data: event.data, schema: event.metadata['encryption'], repository: repo)
    #   decrypted_data = decryptor.call
    class DataDecryptor
      # Decrypts the data attributes specified in the encryption metadata.
      #
      # @return [Hash] the decrypted data
      def call
        return encrypted_data if encryption_metadata.empty?

        result = find_key(encryption_metadata['key'])
        return encrypted_data unless result.success?

        decrypt_attributes(
          key: result.value!,
          data: encrypted_data,
          attributes: encryption_metadata['attributes']
        )
      end

      private

      attr_reader :key_repository, :encryption_metadata, :encrypted_data

      # @param data [Hash] the encrypted event data
      # @param schema [Hash, nil] the encryption metadata from the event
      # @param repository [#find, #decrypt] the key repository
      def initialize(data:, schema:, repository:)
        @encrypted_data = Yes::Core::Utils::HashUtils.deep_dup(data).transform_keys!(&:to_s)
        @key_repository = repository
        @encryption_metadata = schema&.transform_keys(&:to_s) || {}
      end

      def decrypt_attributes(key:, data:, attributes: {}) # rubocop:disable Lint/UnusedMethodArgument
        return data unless key

        res = key_repository.decrypt(key:, message: data['es_encrypted'])
        return data if res.failure?

        decrypted_text = res.value!
        decrypted = JSON.parse(decrypted_text.attributes[:message]).transform_keys(&:to_s)
        decrypted.each { |k, value| data[k] = value if data.key?(k) }
        data.delete('es_encrypted')
        data
      end

      # @return [Dry::Monads::Result]
      def find_key(identifier)
        key_repository.find(identifier)
      end
    end
  end
end
