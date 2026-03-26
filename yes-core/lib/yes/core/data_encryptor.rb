# frozen_string_literal: true

module Yes
  module Core
    # Encrypts event data attributes using a key from the key repository.
    #
    # @example
    #   encryptor = DataEncryptor.new(data: event.data, schema: event.class.encryption_schema, repository: repo)
    #   encryptor.call
    #   encryptor.encrypted_data
    #   encryptor.encryption_metadata
    class DataEncryptor
      # @return [Hash] the encrypted data
      attr_reader :encrypted_data

      # @return [Hash] the encryption metadata (key, iv, attributes)
      attr_reader :encryption_metadata

      # Encrypts the data attributes specified in the schema.
      #
      # @return [Hash] the encrypted data
      def call
        return encrypted_data if encryption_metadata.empty?

        key_id = encryption_metadata[:key]
        res = key_repository.find(key_id)
        res = key_repository.create(key_id) if res.failure?
        key = res.value!

        encryption_metadata[:iv] = key.attributes[:iv]
        encrypt_attributes(
          key:,
          data: encrypted_data,
          attributes: encryption_metadata[:attributes].map(&:to_s)
        )
      end

      private

      attr_reader :key_repository

      # @param data [Hash] the event data
      # @param schema [Hash] the encryption schema
      # @param repository [#find, #create, #encrypt, #decrypt] the key repository
      def initialize(data:, schema:, repository:)
        @encrypted_data = deep_dup(data).transform_keys!(&:to_s)
        @key_repository = repository
        @encryption_metadata = EncryptionMetadata.new(data:, schema:).call
      end

      def encrypt_attributes(key:, data:, attributes:)
        text = JSON.generate(data.select { |hash_key, _value| attributes.include?(hash_key.to_s) })
        encrypted = key_repository.encrypt(key:, message: text).value!
        attributes.each { |att| data[att.to_s] = 'es_encrypted' if data.key?(att.to_s) }
        data['es_encrypted'] = encrypted.attributes[:message]
        data
      end

      def deep_dup(hash)
        return hash unless hash.instance_of?(Hash)

        dupl = hash.dup
        dupl.each { |k, v| dupl[k] = v.instance_of?(Hash) ? deep_dup(v) : v }
        dupl
      end
    end
  end
end
