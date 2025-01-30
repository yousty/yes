# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          # Base class for creating and registering aggregate-related classes
          #
          # This class provides the foundation for resolving and generating various
          # aggregate-related classes such as commands, events, and handlers.
          # It handles class registration and provides a template for class generation.
          #
          # @abstract Subclass and override {#class_type}, {#class_name}, and {#generate_class}
          # to implement specific class resolver behavior
          class Base
            # Creates and registers the class in the Yes::Core configuration
            #
            # @return [Class] The found or generated class that was registered
            def call
              Yes::Core.configuration.register_aggregate_class(
                context_name,
                aggregate_name,
                class_name,
                class_type,
                find_or_generate_class
              )
            end

            private

            # @return [ConstantResolver] The resolver for finding and setting constants
            # @return [ClassNameConvention] The convention for generating class names
            # @return [String] The name of the context
            # @return [String] The name of the aggregate
            attr_reader :constant_resolver, :class_name_convention, :context_name, :aggregate_name

            # @param context_name [String] The name of the context
            # @param aggregate_name [String] The name of the aggregate
            def initialize(context_name, aggregate_name)
              @context_name = context_name
              @aggregate_name = aggregate_name

              @class_name_convention = ClassNameConvention.new(
                context: context_name,
                aggregate: aggregate_name
              )
              @constant_resolver = ConstantResolver.new(class_name_convention)
            end

            # Finds an existing class or generates a new one based on conventions
            #
            # @return [Class] The found or generated class
            def find_or_generate_class
              constant_resolver.find_conventional_class(class_type, class_name) ||
                constant_resolver.set_constant_for(class_type, class_name, generate_class)
            end

            # @abstract
            # @return [Symbol] The type of class being resolved (e.g., :command, :event, :handler)
            def class_type
              raise NotImplementedError, "#{self.class} must implement #class_type"
            end

            # @abstract
            # @return [String] The name of the class to be generated
            def class_name
              raise NotImplementedError, "#{self.class} must implement #class_name"
            end

            # @abstract
            # @return [Class] The generated class
            def generate_class
              raise NotImplementedError, "#{self.class} must implement #generate_class"
            end
          end
        end
      end
    end
  end
end
