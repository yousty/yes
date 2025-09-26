# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Evaluates guards for commands and manages command-specific errors on aggregates
      # Handles the decision of whether to skip guards and properly sets/clears error states
      #
      # @example
      #   runner = GuardRunner.new(aggregate)
      #   evaluator = runner.call(cmd, command_name, guard_evaluator_class, skip_guards: false)
      #
      class GuardRunner
        include Yousty::Eventsourcing::OpenTelemetry::Trackable
        # Initializes a new GuardRunner
        #
        # @param aggregate [Yes::Core::Aggregate] The aggregate instance for error management
        def initialize(aggregate)
          @aggregate = aggregate
        end

        # Evaluates guards for the command
        #
        # @param cmd [Yes::Core::Command] The command to be handled
        # @param command_name [Symbol] The name of the command being executed
        # @param guard_evaluator_class [Class] The guard evaluator class
        # @param skip_guards [Boolean] Whether to skip guard evaluation
        # @return [GuardEvaluator, nil] The guard evaluator instance or nil if guards skipped
        # @raise [GuardEvaluator::InvalidTransition] When the transition is invalid
        # @raise [GuardEvaluator::NoChangeTransition] When no change would occur
        # @raise [Yousty::Eventsourcing::Command::Invalid] When the command is invalid
        def call(cmd, command_name, guard_evaluator_class, skip_guards:)

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
          aggregate.send(:"#{command_name.to_s.underscore}_error=", e.message)
          raise e
        end
        otl_trackable :call,
                      Yousty::Eventsourcing::OpenTelemetry::OtlSpan::OtlData.new(span_name: 'Evaluating guards')

        private

        attr_reader :aggregate

        # Clears command-specific error on aggregate
        #
        # @param command_name [Symbol, String] The command name
        # @return [void]
        def clear_command_error(command_name)
          aggregate.send(:"#{command_name.to_s.underscore}_error=", nil)
        end
      end
    end
  end
end