# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Command
            # Creates and registers guard evaluator classes for aggregate commands
            #
            # This class resolver generates plain guard evaluator class that process
            # commands in aggregates.
            #
            class GuardEvaluator < Base
              private

              # Returns the class type symbol for the guard evaluator
              #
              # @return [Symbol] Returns :guard_evaluator as the class type
              # @api private
              def class_type
                :guard_evaluator
              end

              # Returns the name for the guard evaluator class
              #
              # @return [String] The name of the guard evaluator class derived from the attribute
              # @api private
              def class_name
                command_data.name
              end

              # Creates a new guard evaluator class
              #
              # @return [Class] A new guard evaluator class inheriting from Yes::Core::CommandHandling::GuardEvaluator
              # @api private
              def generate_class
                Class.new(Yes::Core::CommandHandling::GuardEvaluator)
              end
            end
          end
        end
      end
    end
  end
end
