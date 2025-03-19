# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      # Provides command handling functionality for aggregates
      module CommandHandling
        extend ActiveSupport::Concern

        MAX_RETRIES = 5

        EventPublicationData = Yes::Core::CommandHandling::EventPublisher::AggregateEventPublicationData

        private

        # Handles a command using the specified guard evaluator class
        # @param command [Yes::Core::Command] The command to be handled
        # @param guard_evaluator_class [Class] The guard evaluator class to process the command with
        # @return [GuardEvaluator] The guard evaluator instance
        # @raise [CommandHandling::GuardEvaluator::InvalidTransition] If the command transition is invalid
        # @raise [CommandHandling::GuardEvaluator::NoChangeTransition] If the command results in no change
        # @raise [Yousty::Eventsourcing::Command::Invalid] If the command is invalid
        def handle_command(cmd, guard_evaluator_class)
          command_helper = Yousty::Eventsourcing::CommandHelper.new(cmd)

          evaluator = guard_evaluator_class.new(payload: cmd.payload, aggregate: self)
          evaluator.call

          send(:"#{command_helper.command_name.underscore}_error=", nil)

          evaluator
        rescue Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition,
               Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition,
               Yousty::Eventsourcing::Command::Invalid => e
          send(:"#{command_helper.command_name.underscore}_error=", e.message)
          raise e
        end

        # Executes a command within a transaction, handling errors and publishing events
        # @param cmd [Yes::Core::Command] The command to execute
        # @param guard_evaluator_class [Class] The guard evaluator class to process the command
        # @return [Yousty::Eventsourcing::Stateless::CommandResponse] The command response
        # @return [Yousty::Eventsourcing::Stateless::CommandResponse] with error if command handling fails
        def execute_command(cmd, guard_evaluator_class)
          retries = 0

          begin
            evaluator = handle_command(cmd, guard_evaluator_class)

            event = Yes::Core::CommandHandling::EventPublisher.new(
              command: cmd,
              aggregate_data: EventPublicationData.from_aggregate(self),
              accessed_external_aggregates: evaluator.accessed_external_aggregates
            ).call

            command_response_class(cmd).new(cmd:, event:)
          rescue PgEventstore::WrongExpectedRevisionError => e
            retries += 1
            retry if retries < MAX_RETRIES

            command_response_class(cmd).new(cmd:, error: e)
          rescue Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition,
                 Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition,
                 Yousty::Eventsourcing::Command::Invalid => e

            command_response_class(cmd).new(cmd:, error: e)
          end
        end

        def command_response_class(cmd)
          cmd.is_a?(Yousty::Eventsourcing::CommandGroup) ? CommandGroupResponse : CommandResponse
        end
      end
    end
  end
end
