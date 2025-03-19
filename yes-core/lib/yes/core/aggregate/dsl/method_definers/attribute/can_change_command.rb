# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module MethodDefiners
          module Attribute
            # Defines the can_change? method for an attribute
            class CanChangeCommand < Base
              # Defines a method that checks if an attribute can be changed
              # @return [void]
              def call
                can_change_method = :"can_change_#{name}?"
                error_method = :"change_#{name}_error"

                aggregate_class.attr_accessor error_method
                name = @name

                aggregate_class.define_method(can_change_method) do |payload|
                  payload = command_utilities.prepare_payload(name, payload)
                  cmd = command_utilities.build_attribute_command(name, payload)
                  guard_evaluator_class = command_utilities.fetch_attribute_guard_evaluator_class(name)

                  # handle_command returns a guard evaluator instance if successful
                  send(:handle_command, cmd, guard_evaluator_class).present?
                rescue Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition,
                       Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition,
                       Yousty::Eventsourcing::Command::Invalid
                  false
                end
              end
            end
          end
        end
      end
    end
  end
end
