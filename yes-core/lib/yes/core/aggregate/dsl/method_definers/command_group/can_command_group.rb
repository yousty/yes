# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        module MethodDefiners
          module CommandGroup
            # Defines `aggregate.can_<group_name>?(payload = {})` and the
            # `<group_name>_error` accessor on the aggregate class.
            #
            # Mirrors {MethodDefiners::Command::CanCommand} but resolves the
            # group's GuardEvaluator class instead of a command's.
            class CanCommandGroup < Base
              def call
                can_method = :"can_#{@name}?"
                error_method = :"#{@name}_error"

                aggregate_class.attr_accessor error_method
                group_name = @name

                aggregate_class.define_method(can_method) do |payload = {}|
                  cmd = command_utilities.build_group_command(group_name, payload)
                  guard_evaluator_class = command_utilities.fetch_guard_evaluator_class_for_group(group_name)

                  Yes::Core::CommandHandling::GuardRunner.new(self).call(
                    cmd, group_name, guard_evaluator_class, skip_guards: false
                  ).present?
                rescue Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition,
                       Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition,
                       Yes::Core::Command::Invalid
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
