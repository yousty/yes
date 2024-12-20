# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module AttributeMethodDefiners
        # Base class for attribute method definers that provides common functionality
        # for defining attribute-related methods on aggregate classes.
        #
        # @abstract Subclass and override {#call} to implement custom attribute method definition
        class Base
          # Initializes a new attribute method definer
          #
          # @param attribute_data [Object] Object containing attribute configuration
          # @option attribute_data [Symbol] :name The attribute name
          # @option attribute_data [Class] :aggregate_class The target aggregate class where methods will be defined
          def initialize(attribute_data)
            @name = attribute_data.name
            @aggregate_class = attribute_data.aggregate_class
          end

          # Defines the attribute-related methods on the aggregate class
          #
          # @abstract
          # @raise [NotImplementedError] when called on the base class
          # @return [void]
          def call
            raise NotImplementedError, "#{self.class} must implement #call"
          end

          private

          attr_reader :name, :aggregate_class
        end
      end
    end
  end
end
