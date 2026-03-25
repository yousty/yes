# frozen_string_literal: true

# A simple implementation of in-memory key repo storage and simple encryptor/decryptor.
# Used by encryption-related specs to emulate encryption/decryption lifecycle.
class DummyRepository
  Message = Struct.new(:attributes)

  # Simple Result monad replacement for specs (avoids dry-monads dependency)
  class Success
    attr_reader :value

    # @param value [Object]
    def initialize(value)
      @value = value
    end

    # @return [true]
    def success?
      true
    end

    # @return [false]
    def failure?
      false
    end

    # @return [Object]
    def value!
      value
    end
  end

  # Simple Failure monad replacement for specs (avoids dry-monads dependency)
  class Failure
    attr_reader :value

    # @param value [Object]
    def initialize(value)
      @value = value
    end

    # @return [false]
    def success?
      false
    end

    # @return [true]
    def failure?
      true
    end
  end

  # @attr_accessor [String] iv
  # @attr_accessor [String] cipher
  # @attr_accessor [String] id
  class Key
    attr_accessor :iv, :cipher, :id

    # @param id [String]
    def initialize(id:, **)
      @id = id
    end

    # @return [Hash]
    def attributes
      {}
    end
  end

  class << self
    attr_accessor :repository

    # @return [void]
    def reset
      self.repository = {}
    end

    # @param str [String]
    # @return [String]
    def encrypt(str)
      Base64.encode64(str)
    end

    # @param str [String]
    # @return [String]
    def decrypt(str)
      Base64.decode64(str)
    end
  end
  reset

  # @param user_id [String]
  # @return [DummyRepository::Success]
  def find(user_id)
    Success.new(Key.new(id: user_id))
  end

  # @param key [DummyRepository::Key]
  # @param message [String]
  # @return [DummyRepository::Success]
  def encrypt(key:, message:)
    self.class.repository[key.id] = self.class.encrypt(message)
    message = Message.new({ message: self.class.repository[key.id] })
    Success.new(message)
  end

  # @param key [DummyRepository::Key]
  # @param message [String]
  # @return [DummyRepository::Success]
  def decrypt(key:, message:)
    decrypted =
      if self.class.repository[key.id]
        self.class.decrypt(self.class.repository[key.id])
      else
        {}.to_json
      end
    message = Message.new({ message: decrypted })
    Success.new(message)
  end
end
