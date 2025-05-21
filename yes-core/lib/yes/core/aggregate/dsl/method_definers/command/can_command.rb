# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module MethodDefiners
          module Command
            # Defines a can_<command_name>? method on the aggregate class
            class CanCommand < Base
              # @return [void]
              def call
                can_change_method = :"can_#{name}?"
                error_method = :"#{name}_error"

                aggregate_class.attr_accessor error_method
                command_name = @name

                aggregate_class.define_method(can_change_method) do |payload = {}|
                  payload = command_utilities.prepare_command_payload(command_name, payload, self.class)
                  payload = command_utilities.prepare_assign_command_payload(command_name, payload)
                  cmd = command_utilities.build_command(command_name, payload)
                  guard_evaluator_class = command_utilities.fetch_guard_evaluator_class(command_name)

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
