# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      module Dsl
        # Factory class that creates and defines command_groups on aggregates.
        #
        # Mirrors {CommandDefiner}. The DSL evaluator inside accepts two
        # methods: `command :sub_command_name` to push a sub-command symbol,
        # and `guard(name, error_extra: …) { … }` to register a group-level
        # guard on the generated GuardEvaluator class.
        #
        # @example
        #   group_data = CommandGroupData.new(:create_apprenticeship, MyAggregate,
        #                                     context: 'Companies', aggregate: 'Apprenticeship')
        #   CommandGroupDefiner.new(group_data).call do
        #     command :assign_company
        #     command :change_name
        #
        #     guard(:company_assigned) { company_id.present? }
        #   end
        class CommandGroupDefiner
          # Raised when an unknown sub-command name is referenced.
          class UnknownSubCommandError < Yes::Core::Error; end

          attr_reader :command_group_data
          private :command_group_data

          # @param command_group_data [CommandGroupData]
          def initialize(command_group_data)
            @command_group_data = command_group_data
          end

          # Generates and registers all classes/methods for the command group.
          #
          # @yield Block for declaring sub-commands and guards
          # @return [void]
          def call(&block)
            create_and_register_guard_evaluator
            evaluate_dsl_block(&block) if block
            create_and_register_command
            define_aggregate_methods
          end

          private

          def create_and_register_guard_evaluator
            @guard_evaluator_class = ClassResolvers::CommandGroup::GuardEvaluator.new(command_group_data).call
          end

          def create_and_register_command
            ClassResolvers::CommandGroup::Command.new(command_group_data).call
          end

          def define_aggregate_methods
            MethodDefiners::CommandGroup::CommandGroup.new(command_group_data).call
            MethodDefiners::CommandGroup::CanCommandGroup.new(command_group_data).call
          end

          def evaluate_dsl_block(&)
            DslEvaluator.new(command_group_data, @guard_evaluator_class).instance_eval(&)
          end

          # DSL evaluator that backs the `command_group :name do … end` block.
          class DslEvaluator
            attr_reader :command_group_data, :guard_evaluator_class

            def initialize(command_group_data, guard_evaluator_class)
              @command_group_data = command_group_data
              @guard_evaluator_class = guard_evaluator_class
            end

            # Declare a sub-command. Order is preserved as execution order.
            #
            # @param name [Symbol] the sub-command name (must match a command
            #   declared on the same aggregate)
            # @return [void]
            def command(name)
              command_group_data.add_sub_command(name.to_sym)
            end

            # Register a group-level guard. Semantics match the per-command
            # `guard` DSL — `:no_change` is recognized as the magic name that
            # raises {NoChangeTransition} on failure.
            #
            # @param name [Symbol] the guard name
            # @param error_extra [Hash, Proc] extra error context
            # @yield Block returning true if the guard passes
            # @return [void]
            def guard(name, error_extra: {}, &)
              command_group_data.add_guard(name)
              guard_evaluator_class.guard(name, error_extra:, &)
            end
          end
        end
      end
    end
  end
end
