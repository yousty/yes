# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        # Factory class that creates the appropriate attribute definer based on the attribute type
        #
        # @example
        #   attribute_data = AttributeData.new(name: :name, type: :string, aggregate_class: User, validate: true)
        #   AttributeDefiner.new(attribute_data).call do
        #     guard :no_change do
        #       payload.name == name
        #     end
        #   end
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

          # Creates the appropriate definer and calls it to generate the necessary classes and methods
          #
          # @yield Block for defining guards and other attribute configurations
          # @yieldreturn [void]
          # @return [void]
          def call(&)
            definer_for_type.new(attribute_data).call(&)
          end

          private

          # Returns the appropriate definer class based on the attribute type
          #
          # @return [Class] The definer class to use
          def definer_for_type
            case attribute_data.type
            when :aggregate then AttributeDefiners::Aggregate
            else AttributeDefiners::Standard
            end
          end
        end
      end
    end
  end
end
