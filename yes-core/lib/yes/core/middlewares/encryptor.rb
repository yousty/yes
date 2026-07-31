# frozen_string_literal: true

module Yes
  module Core
    module Middlewares
      # PgEventstore middleware for encrypting/decrypting event data.
      #
      # Register it through {Middlewares.register_encryptor} rather than by hand, so its write-only
      # counterpart ({WriteEncryptor}) is always registered alongside it.
      #
      # @example
      #   PgEventstore.configure do |config|
      #     Yes::Core::Middlewares.register_encryptor(key_repository, config:)
      #   end
      class Encryptor
        include PgEventstore::Middleware

        attr_reader :key_repository
        private :key_repository

        # @param key_repository [#find, #create, #encrypt, #decrypt]
        def initialize(key_repository)
          @key_repository = key_repository
        end

        # @param event [PgEventstore::Event]
        # @return [PgEventstore::Event]
        def serialize(event)
          return event unless event.class.respond_to?(:encryption_schema)
          # Idempotence guard. With {WriteEncryptor} registered, the DEFAULT middleware list holds two
          # serialize-capable encryptors, so an append that omits `middlewares:` would encrypt twice. The
          # second pass would encrypt the sentinels written by the first and overwrite the real ciphertext,
          # which cannot be recovered. It also guards re-appending an event that was read at rest.
          return event if event.data[DataEncryptor::CIPHERTEXT_KEY].present?

          encryptor = DataEncryptor.new(
            data: event.data, schema: event.class.encryption_schema, repository: key_repository
          )
          encryptor.call
          event.data = encryptor.encrypted_data
          event.metadata['encryption'] = encryptor.encryption_metadata
          event
        end

        # @param event [PgEventstore::Event]
        # @return [PgEventstore::Event]
        def deserialize(event)
          decrypted_data =
            DataDecryptor.new(data: event.data, schema: event.metadata['encryption'], repository: key_repository).call
          event.data = decrypted_data
          event
        end
      end
    end
  end
end
