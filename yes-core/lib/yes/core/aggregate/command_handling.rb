# frozen_string_literal: true

module Yes
  module Core
    class Aggregate
      # Provides command handling functionality for aggregates
      module CommandHandling
        extend ActiveSupport::Concern

        MAX_RETRIES = 5

        EventPublicationData = Yes::Core::CommandHandling::EventPublisher::AggregateEventPublicationData

        def update_read_model_with_revision_guard(
          event, command_payload, command_name = command_utilities.command_name_from_event(event, self.class)
        )
          locale = command_payload.delete(:locale)

          state_updater_class = command_utilities.fetch_state_updater_class(command_name)

          Yes::Core::CommandHandling::ReadModelRevisionGuard.call(
            read_model, event.stream_revision, revision_column:
          ) do
            state_updater = state_updater_class.new(
              payload: command_payload.except(*Yousty::Eventsourcing::Command::RESERVED_KEYS),
              aggregate: self,
              event: event
            )
            update_read_model(state_updater.call.merge(revision_column => event.stream_revision, locale:))
          end
        end

        private

        # Handles a command using the specified guard evaluator class
        # @param cmd [Yes::Core::Command] The command to be handled
        # @param guard_evaluator_class [Class] The guard evaluator class to process the command with
        # @return [GuardEvaluator] The guard evaluator instance
        # @raise [CommandHandling::GuardEvaluator::InvalidTransition] If the command transition is invalid
        # @raise [CommandHandling::GuardEvaluator::NoChangeTransition] If the command results in no change
        # @raise [Yousty::Eventsourcing::Command::Invalid] If the command is invalid
        def handle_command(cmd, guard_evaluator_class)
          command_helper = Yousty::Eventsourcing::CommandHelper.new(cmd)

          evaluator = guard_evaluator_class.new(
            payload: cmd.payload,
            aggregate: self,
            command_name: command_helper.command_name
          )
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

            command_response_class(cmd).new(cmd:, error: e, extra: e.try(:extra), batch_id: cmd.batch_id)
          end
        end

        def execute_command_and_update_state(command_name, payload)
          payload = command_utilities.prepare_command_payload(command_name, payload.clone, self.class)
          payload = command_utilities.prepare_assign_command_payload(command_name, payload)
          cmd = command_utilities.build_command(command_name, payload)
          guard_evaluator_class = command_utilities.fetch_guard_evaluator_class(command_name)

          response = execute_command(cmd, guard_evaluator_class)

          update_read_model_with_revision_guard(response.event, payload, command_name) if response.success?

          response
        end

        def command_response_class(cmd)
          cmd.is_a?(Yousty::Eventsourcing::CommandGroup) ? CommandGroupResponse : CommandResponse
        end
      end
    end
  end
end
