# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module ClassResolvers
          module Attribute
            # Creates and registers guard evaluator classes for aggregate attributes
            #
            # This class resolver generates guard evaluator classes that process
            # attribute modifications in aggregates. Each guard evaluator class is automatically
            # configured with validation logic to check if the attribute value is
            # actually changing before emitting an event.
            #
            # @example Generated guard evaluator class structure
            #   class ChangeUserEmailGuardEvaluator < Yes::Core::CommandHandling::GuardEvaluator
            #     guard :no_change do
            #       email != payload.email
            #     end
            #   end
            class GuardEvaluator < Base
              private

              # @return [Symbol] Returns :guard_evaluator as the class type
              def class_type
                :guard_evaluator
              end

              # @return [String] The name of the guard evaluator class derived from the attribute
              def class_name
                attribute_data.command_name
              end

              # Generates a new guard evaluator class with the required validation methods
              #
              # @return [Class] A new guard evaluator class inheriting from Yes::Core::CommandHandling::GuardEvaluator
              def generate_class
                attribute_name = attribute_data.name
                attribute_type = attribute_data.type

                Class.new(Yes::Core::CommandHandling::GuardEvaluator) do
                  guard :no_change do
                    attribute_key = attribute_type == :aggregate ? :"#{attribute_name}_id" : attribute_name
                    current_value = public_send(attribute_key)
                    new_value = payload.public_send(attribute_key)
                    current_value != new_value
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
