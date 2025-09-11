# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Evaluates guards for commands and manages command-specific errors on aggregates
      # Handles the decision of whether to skip guards and properly sets/clears error states
      #
      # @example
      #   runner = GuardRunner.new(aggregate)
      #   evaluator = runner.call(cmd, guard_evaluator_class, skip_guards: false)
      #
      class GuardRunner
        # Initializes a new GuardRunner
        #
        # @param aggregate [Yes::Core::Aggregate] The aggregate instance for error management
        def initialize(aggregate)
          @aggregate = aggregate
        end

        # Evaluates guards for the command
        #
        # @param cmd [Yes::Core::Command] The command to be handled
        # @param guard_evaluator_class [Class] The guard evaluator class
        # @param skip_guards [Boolean] Whether to skip guard evaluation
        # @return [GuardEvaluator, nil] The guard evaluator instance or nil if guards skipped
        # @raise [GuardEvaluator::InvalidTransition] When the transition is invalid
        # @raise [GuardEvaluator::NoChangeTransition] When no change would occur
        # @raise [Yousty::Eventsourcing::Command::Invalid] When the command is invalid
        def call(cmd, guard_evaluator_class, skip_guards:)
          command_helper = Yousty::Eventsourcing::CommandHelper.new(cmd)
          command_name = command_helper.command_name

          if skip_guards
            clear_command_error(command_name)
            return nil
          end

          evaluator = guard_evaluator_class.new(
            payload: cmd.payload,
            metadata: cmd.metadata,
            aggregate: aggregate,
            command_name: command_name
          )
          evaluator.call

          clear_command_error(command_name)
          
          evaluator
        rescue GuardEvaluator::InvalidTransition,
               GuardEvaluator::NoChangeTransition,
               Yousty::Eventsourcing::Command::Invalid => e
          aggregate.send(:"#{command_name.underscore}_error=", e.message)
          raise e
        end

        private

        attr_reader :aggregate

        # Clears command-specific error on aggregate
        #
        # @param command_name [String] The command name
        # @return [void]
        def clear_command_error(command_name)
          aggregate.send(:"#{command_name.underscore}_error=", nil)
        end
      end
    end
  end
end