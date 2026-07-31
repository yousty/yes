# frozen_string_literal: true

module Yes
  module Core
    module Middlewares
      # Config key of the encryptor used on read paths: encrypts on #serialize, decrypts on #deserialize.
      ENCRYPTOR = :encryptor
      # Config key of the encryptor used on write paths: encrypts on #serialize, no-op on #deserialize.
      WRITE_ENCRYPTOR = :write_encryptor

      class << self
        # Registers both encryptor middlewares against the same key repository.
        #
        # Always use this instead of assigning config.middlewares[:encryptor] by hand: registering the
        # decrypting encryptor without its write-only twin silently doubles the encryptor round trips every
        # encrypted append performs (see {WriteEncryptor}).
        #
        # Mutates the given config in place rather than opening its own PgEventstore.configure block, because
        # PgEventstore.configure takes a non-reentrant mutex - nesting one inside another deadlocks.
        #
        # @param key_repository [#find, #create, #encrypt, #decrypt]
        # @param config [PgEventstore::Config] the config yielded by PgEventstore.configure
        # @return [void]
        def register_encryptor(key_repository, config: PgEventstore.config)
          config.middlewares[ENCRYPTOR] = Encryptor.new(key_repository)
          config.middlewares[WRITE_ENCRYPTOR] = WriteEncryptor.new(key_repository)
        end

        # Middleware keys to pass to #append_to_stream: every configured middleware, with the decrypting
        # encryptor swapped for the write-only one.
        #
        # Derived from the live config, never hard-coded. PgEventstore::Client resolves a passed list with
        # `config.middlewares.slice(*list)`, which silently drops names that are not registered - so a literal
        # list would resolve to one with NO encryptor at all against a config that registered it under a
        # different key, and would write plaintext at rest undetectably. Deriving the list makes that
        # impossible, and picks up any middleware added later for free.
        #
        # Falls back to the full list when {WRITE_ENCRYPTOR} is not registered. That is correct, just as slow
        # as before - unlike a hard-coded list, which would drop encryption altogether.
        #
        # @return [Array<Symbol>]
        def for_write
          keys = PgEventstore.config.middlewares.keys
          return keys unless keys.include?(WRITE_ENCRYPTOR)

          keys - [ENCRYPTOR]
        end

        # Returns middleware keys excluding the specified one.
        #
        # Note that excluding {ENCRYPTOR} still yields a list containing {WRITE_ENCRYPTOR}, whose #deserialize
        # is a no-op - so `without(:encryptor)` keeps meaning "read the data as it is stored".
        #
        # @param middleware_name [Symbol] the middleware key to exclude
        # @return [Array<Symbol>] remaining middleware keys
        def without(middleware_name)
          PgEventstore.config.middlewares.except(middleware_name).keys
        end
      end
    end
  end
end
