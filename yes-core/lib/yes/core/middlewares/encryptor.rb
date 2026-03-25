# frozen_string_literal: true

module Yes
  module Core
    module Middlewares
      # PgEventstore middleware for encrypting/decrypting event data.
      #
      # @example
      #   PgEventstore.configure do |config|
      #     config.middlewares[:encryptor] = Yes::Core::Middlewares::Encryptor.new(key_repository)
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
