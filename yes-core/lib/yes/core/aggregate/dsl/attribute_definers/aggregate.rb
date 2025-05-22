# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module AttributeDefiners
          # Handles the definition and generation of aggregate attribute-related classes and methods
          class Aggregate
            # @return [AttributeData] the data object containing attribute configuration
            attr_reader :attribute_data, :guard_evaluator_class

            private :attribute_data, :guard_evaluator_class

            # Initializes a new Base instance
            #
            # @param attribute_data [AttributeData] the data object containing attribute configuration
            # @return [Base] a new instance of Base
            def initialize(attribute_data)
              @attribute_data = attribute_data
            end

            # Generates and registers all necessary classes for the attribute.
            #
            # @yield Block for defining guards and other attribute configurations
            # @yieldreturn [void]
            # @return [void]
            def call
              MethodDefiners::Attribute::AggregateAccessor.new(attribute_data).call
            end
          end
        end
      end
    end
  end
end
