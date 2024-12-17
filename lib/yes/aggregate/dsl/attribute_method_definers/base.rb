# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module AttributeMethodDefiners
        # Base class for attribute method definers
        class Base
          # @param name [Symbol] The attribute name
          # @param aggregate_class [Class] The target aggregate class
          def initialize(name, aggregate_class)
            @name = name
            @aggregate_class = aggregate_class
          end

          # Defines the method on the aggregate class
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