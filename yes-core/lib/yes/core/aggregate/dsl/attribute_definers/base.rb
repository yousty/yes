# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module AttributeDefiners
          # Base class for attribute definers that handles common functionality
          class Base
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
            # This includes command classes, event classes, and guard evaluator classes,
            # as well as defining related methods on the aggregate class.
            #
            # @param block [Proc] Optional block for defining guards and other attribute configurations
            # @return [void]
            def call(&block)
              define_classes if define_command?
              define_methods
              evaluate_dsl_block(&block) if block
              register_command_events if define_command?
            end

            private

            # Defines the command, event, and guard evaluator classes for the attribute
            #
            # @return [void]
            def define_classes
              ClassResolvers::Attribute::Command.new(attribute_data).call
              ClassResolvers::Attribute::Event.new(attribute_data).call
              @guard_evaluator_class = ClassResolvers::Attribute::GuardEvaluator.new(attribute_data).call
            end

            # Defines methods on the aggregate class
            # This method must be implemented by subclasses
            #
            # @return [void]
            def define_methods
              raise NotImplementedError, "#{self.class} must implement #define_methods"
            end

            def register_command_events
              Yes::Core.configuration.register_command_events(
                attribute_data.context_name,
                attribute_data.aggregate_name,
                :"change_#{attribute_data.name}",
                [attribute_data.event_name]
              )
            end

            # Evaluates the DSL block in the context of a DslEvaluator
            #
            # @param block [Proc] The block to evaluate
            # @return [void]
            def evaluate_dsl_block(&block)
              return unless block

              dsl_evaluator = DslEvaluator.new(attribute_data, guard_evaluator_class)
              dsl_evaluator.instance_eval(&block)
            end

            def define_command?
              attribute_data.define_command
            end

            # DSL evaluator class for attribute configuration blocks
            class DslEvaluator
              # @return [AttributeData] The attribute data being configured
              # @return [Class] The guard evaluator class for this attribute
              attr_reader :attribute_data, :guard_evaluator_class

              # @param attribute_data [AttributeData] The attribute data to configure
              # @param guard_evaluator_class [Class] The guard evaluator class for this attribute
              def initialize(attribute_data, guard_evaluator_class)
                @attribute_data = attribute_data
                @guard_evaluator_class = guard_evaluator_class
              end

              # Defines a guard for the attribute
              #
              # @param name [Symbol] The name of the guard
              # @param block [Proc] The guard evaluation block
              # @return [void]
              def guard(name, &)
                guard_evaluator_class.guard(name, &)
              end
            end
          end
        end
      end
    end
  end
end
