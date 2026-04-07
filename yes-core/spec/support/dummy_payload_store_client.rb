# frozen_string_literal: true

class DummyPayloadStoreClient
  PayloadResource = Struct.new(:id, :attributes, keyword_init: true)

  class << self
    attr_accessor :repository

    def reset
      self.repository = {}
    end

    # @param value
    # @return [String]
    def add(value)
      key = "#{Yes::Core::Event::PAYLOAD_STORE_VALUE_PREFIX}#{SecureRandom.uuid}"
      repository[key] = value.as_json
      key
    end
  end
  reset

  # @param payload_keys [Array<String>]
  # @return [Dry::Monads::Success<Array<PayloadResource>>]
  def get_payloads(payload_keys)
    payloads = self.class.repository.slice(*payload_keys).map do |key, value|
      id = key.gsub(Yes::Core::Event::PAYLOAD_STORE_VALUE_PREFIX, '')
      PayloadResource.new(
        id:,
        attributes: { key:, value: }
      )
    end
    Dry::Monads::Success(payloads)
  end
end
