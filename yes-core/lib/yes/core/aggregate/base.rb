# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      # Base class for all aggregates
      class Base
        # @return [String] The ID of the aggregate
        attr_reader :id

        # @param id [String] The ID of the aggregate
        def initialize(id)
          @id = id
        end

        private

        # Executes a command with guard evaluation
        #
        # @param command [Yes::Core::Command] The command to execute
        # @param guard_evaluator_class [Class] The guard evaluator class
        # @return [Yes::Core::CommandResponse] The command response
        def execute_command(command, guard_evaluator_class)
          guard_evaluator = guard_evaluator_class.new(payload: command.to_h, aggregate: self)
          guard_evaluator.call

          # Execute command logic and return response
          # This should be implemented by subclasses
          raise NotImplementedError
        end

        # Updates the read model with the given attributes
        #
        # @param attributes [Hash] The attributes to update
        # @return [void]
        def update_read_model(attributes)
          # This should be implemented by subclasses
          raise NotImplementedError
        end
      end
    end
  end
end
