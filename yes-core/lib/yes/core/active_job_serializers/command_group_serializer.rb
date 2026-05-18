# frozen_string_literal: true

module Yes
  module Core
    module ActiveJobSerializers
      # ActiveJob serializer for {Yes::Core::Commands::Group} (legacy stateless
      # cross-aggregate groups) and {Yes::Core::Commands::CommandGroup}
      # (aggregate-DSL groups). Both round-trip through `to_h` / `Class.new`.
      class CommandGroupSerializer < ActiveJob::Serializers::ObjectSerializer
        # @param argument [Object] the argument to check
        # @return [Boolean] true if the argument can be serialized
        def serialize?(argument)
          argument.is_a?(Yes::Core::Commands::Group) ||
            argument.is_a?(Yes::Core::Commands::CommandGroup)
        end

        # @param command_group [Yes::Core::Commands::Group, Yes::Core::Commands::CommandGroup]
        # @return [Hash] the serialized representation
        def serialize(command_group)
          super(command_group.to_h.merge(_type: command_group.class.name))
        end

        # @param hash [Hash] the serialized representation
        # @return [Yes::Core::Commands::Group, Yes::Core::Commands::CommandGroup]
        def deserialize(hash)
          symbolized_hash = hash.deep_symbolize_keys
          Object.const_get(symbolized_hash[:_type]).new(symbolized_hash.except(:_aj_serialized, :_type))
        end
      end
    end
  end
end
