# frozen_string_literal: true

module Yes
  module Core
    module Utils
      # Utility class for deep hash operations
      class HashUtils
        class << self
          # Returns a hash with the keys flattened
          #
          # @param obj [Hash, Array] the object to flatten
          # @param prefix [String] the key to use as a prefix for the keys in the hash
          # @param memo [Hash] the hash to store the flattened keys and values
          # @return [Hash] the flattened hash
          #
          # @example
          #   HashUtils.deep_flatten_hash({ name: 'A', otl_contexts: { root: { attr: 10, available: true } } })
          #    => {"name"=>"A", "otl_contexts.root.attr"=>10, "otl_contexts.root.available"=>true}
          def deep_flatten_hash(obj, prefix = nil, memo = {})
            case obj
            when Hash
              obj.each do |key, value|
                case [key, value]
                in Hash, Array
                  memo[deep_flatten_hash(key)] = memo[deep_flatten_hash(value)]
                in String | Symbol, Hash
                  deep_flatten_hash(value, prefix ? "#{prefix}.#{key}" : key.to_s, memo)
                in String | Symbol, Array
                  memo[key.to_s] = deep_flatten_hash(value)
                in Array, _
                  memo[deep_flatten_hash(key)] = deep_flatten_hash(value)
                else
                  memo[prefix ? "#{prefix}.#{key}" : key.to_s] = value
                end
              end
              memo
            when Array
              obj.map { deep_flatten_hash(_1) }
            else
              obj
            end
          end
        end
      end
    end
  end
end
