# frozen_string_literal: true

module Yes
  module Core
    module ActiveJobSerializers
      # ActiveJob serializer for CommandGroup objects.
      class CommandGroupSerializer < ActiveJob::Serializers::ObjectSerializer
        # @param argument [Object] the argument to check
        # @return [Boolean] true if the argument can be serialized
        def serialize?(argument)
          argument.is_a? Yes::Core::Commands::Group
        end

        # @param command_group [Yes::Core::Commands::Group] the command group to serialize
        # @return [Hash] the serialized representation
        def serialize(command_group)
          super(command_group.to_h.merge(_type: command_group.class.name))
        end

        # @param hash [Hash] the serialized representation
        # @return [Yes::Core::Commands::Group] the deserialized command group
        def deserialize(hash)
          symbolized_hash = hash.deep_symbolize_keys
          Object.const_get(symbolized_hash[:_type]).new(symbolized_hash.except(:_aj_serialized, :_type))
        end
      end
    end
  end
end
