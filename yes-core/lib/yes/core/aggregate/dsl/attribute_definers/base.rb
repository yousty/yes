# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module AttributeDefiners
          # Base class for attribute definers that handles common functionality
          class Base
            # @return [AttributeData] the data object containing attribute configuration
            attr_reader :attribute_data
            private :attribute_data

            # Initializes a new Base instance
            #
            # @param attribute_data [AttributeData] the data object containing attribute configuration
            # @return [Base] a new instance of Base
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

            # Defines methods on the aggregate class
            # This method must be implemented by subclasses
            #
            # @return [void]
            def define_methods
              raise NotImplementedError, "#{self.class} must implement #define_methods"
            end
          end
        end
      end
    end
  end
end
