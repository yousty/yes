# frozen_string_literal: true

module Yes
  module Core
    module ActiveJobSerializers
      # ActiveJob serializer for Dry::Struct objects (including Commands).
      class DryStructSerializer < ActiveJob::Serializers::ObjectSerializer
        # @param argument [Object] the argument to check
        # @return [Boolean] true if the argument can be serialized
        def serialize?(argument)
          argument.is_a? Dry::Struct
        end

        # @param dry_struct [Dry::Struct] the dry struct to serialize
        # @return [Hash] the serialized representation
        def serialize(dry_struct)
          super(dry_struct.attributes.merge(_type: dry_struct.class.name).as_json)
        end

        # @param hash [Hash] the serialized representation
        # @return [Dry::Struct] the deserialized object
        def deserialize(hash)
          symbolized_hash = hash.deep_symbolize_keys
          object = Object.const_get(symbolized_hash[:_type])

          if object < Yes::Core::Command
            deserialize_command(symbolized_hash, object)
          else
            object.new(symbolized_hash.except(:_aj_serialized, :_type))
          end
        end

        private

        # @param symbolized_hash [Hash] the symbolized hash
        # @param object [Class] the command class
        # @return [Yes::Core::Command] the deserialized command
        def deserialize_command(symbolized_hash, object)
          if symbolized_hash[:transaction].is_a?(Hash) && symbolized_hash[:transaction][:otl_contexts].present?
            symbolized_hash[:transaction] = Yes::Core::TransactionDetails.new(
              **symbolized_hash[:transaction].except(:otl_contexts),
              otl_contexts: Yes::Core::TransactionDetailsTypes::OtlContexts.new(
                symbolized_hash[:transaction][:otl_contexts]
              )
            )

            return object.new(symbolized_hash.except(:_aj_serialized, :_type))
          end

          symbolized_hash[:transaction] = Yes::Core::TransactionDetails.new(symbolized_hash[:transaction]) if symbolized_hash[:transaction].is_a?(Hash)

          object.new(symbolized_hash.except(:_aj_serialized, :_type))
        end
      end
    end
  end
end
