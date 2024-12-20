# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      # Handles the definition and generation of attribute-related classes for aggregates.
      # This includes commands, events, and handlers for attribute changes.
      #
      # @example
      #   attribute_data = AttributeData.new(name: :name, type: :string, aggregate_class: User, validate: true)
      #   AttributeDefiner.new(attribute_data).call
      #
      class AttributeDefiner
        # @return [AttributeData] the data object containing attribute configuration
        attr_reader :attribute_data
        private :attribute_data

        # Initializes a new AttributeDefiner instance
        #
        # @param attribute_data [AttributeData] the data object containing attribute configuration
        # @return [AttributeDefiner] a new instance of AttributeDefiner
        def initialize(attribute_data)
          @attribute_data = attribute_data
        end

        # Generates and registers all necessary classes for the attribute.
        # This includes command classes, event classes, and handler classes,
        # as well as defining related methods on the aggregate class.
        #
        # @return [void]
        def call
          define_classes
          define_methods
        end

        private

        # Defines the command, event, and handler classes for the attribute
        #
        # @return [void]
        def define_classes
          ClassResolvers::Command.new(attribute_data).call
          ClassResolvers::Event.new(attribute_data).call
          ClassResolvers::Handler.new(attribute_data).call
        end

        # Defines methods on the aggregate class for
        #   - handling attribute changes
        #   - accessing the state of the attribute
        #
        # @return [void]
        def define_methods
          AttributeMethodDefiners::ChangeCommand.new(attribute_data).call
          AttributeMethodDefiners::CanChangeCommand.new(attribute_data).call
          AttributeMethodDefiners::Accessor.new(attribute_data).call
        end
      end
    end
  end
end
