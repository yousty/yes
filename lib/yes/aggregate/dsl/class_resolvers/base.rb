# frozen_string_literal: true

module Yes
  class Aggregate
    module DSL
      module ClassResolvers
        # Base class for creating aggregate-related classes
        #
        # @abstract
        class Base
          # @param attribute [Yes::Aggregate::DSL::Attribute] The attribute instance
          def initialize(attribute)
            @attribute = attribute
            @class_name_convention = ClassNameConvention.new(
              context: context_name,
              aggregate: aggregate_name
            )
            @constant_resolver = ConstantResolver.new(class_name_convention)
          end

          # Creates and registers the class
          # @abstract
          def call
            Yes.configuration.register_aggregate_class(
              context_name,
              aggregate_name,
              class_name,
              class_type,
              find_or_generate_class
            )
          end

          private

          attr_reader :attribute, :constant_resolver, :class_name_convention

          def find_or_generate_class
            constant_resolver.find_conventional_class(class_type, class_name) ||
              constant_resolver.set_constant_for(class_type, class_name, generate_class)
          end

          def context_name
            attribute.send(:context_name)
          end

          def aggregate_name
            attribute.send(:aggregate_name)
          end

          def class_type
            raise NotImplementedError, "#{self.class} must implement #class_type"
          end

          def class_name
            raise NotImplementedError, "#{self.class} must implement #class_name"
          end

          def generate_class
            raise NotImplementedError, "#{self.class} must implement #generate_class"
          end
        end
      end
    end
  end
end 