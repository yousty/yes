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
            # Clear pending state when updating read model
            update_read_model(state_updater.call.merge(
              revision_column => event.stream_revision,
              locale:,
              pending_update_since: nil
            ))
          end
        end

        private

        # Handles a command using the specified guard evaluator class
        # @param cmd [Yes::Core::Command] The command to be handled
        # @param guard_evaluator_class [Class] The guard evaluator class to process the command with
        # @param skip_guards [Boolean] Whether to skip guard evaluation
        # @return [GuardEvaluator, nil] The guard evaluator instance or nil if guards are skipped
        # @raise [CommandHandling::GuardEvaluator::InvalidTransition] If the command transition is invalid
        # @raise [CommandHandling::GuardEvaluator::NoChangeTransition] If the command results in no change
        # @raise [Yousty::Eventsourcing::Command::Invalid] If the command is invalid
        def handle_command(cmd, guard_evaluator_class, skip_guards: false)
          command_helper = Yousty::Eventsourcing::CommandHelper.new(cmd)

          if skip_guards
            send(:"#{command_helper.command_name.underscore}_error=", nil)
            return nil
          end

          evaluator = guard_evaluator_class.new(
            payload: cmd.payload,
            metadata: cmd.metadata,
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
        # @param skip_guards [Boolean] Whether to skip guard evaluation
        # @return [Yousty::Eventsourcing::Stateless::CommandResponse] The command response
        # @return [Yousty::Eventsourcing::Stateless::CommandResponse] with error if command handling fails
        def execute_command(cmd, guard_evaluator_class, skip_guards: false)
          retries = 0

          begin
            evaluator = handle_command(cmd, guard_evaluator_class, skip_guards:)

            # Set pending state after guards pass but before publishing event
            set_pending_update_state

            begin
              event = Yes::Core::CommandHandling::EventPublisher.new(
                command: cmd,
                aggregate_data: EventPublicationData.from_aggregate(self),
                accessed_external_aggregates: evaluator&.accessed_external_aggregates || []
              ).call
            rescue StandardError => e
              # Clear pending state if event publication fails
              clear_pending_update_state
              raise e
            end

            command_response_class(cmd).new(cmd:, event:)
          rescue PgEventstore::WrongExpectedRevisionError => e
            retries += 1

            if retries < MAX_RETRIES
              # Clear pending state before retry
              clear_pending_update_state
              retry
            end

            # Clear pending state after max retries exceeded
            clear_pending_update_state
            command_response_class(cmd).new(cmd:, error: e)
          rescue Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition,
                 Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition,
                 Yousty::Eventsourcing::Command::Invalid => e

            command_response_class(cmd).new(cmd:, error: e, extra: e.try(:extra), batch_id: cmd.batch_id)
          end
        end

        def execute_command_and_update_state(command_name, payload, guards: true)
          # Check and recover if read model is in pending state, passing the aggregate instance
          Yes::Core::CommandHandling::ReadModelRecoveryService.check_and_recover_with_retries(read_model, aggregate: self)

          payload = command_utilities.prepare_command_payload(command_name, payload.clone, self.class)
          payload = command_utilities.prepare_assign_command_payload(command_name, payload)

          if draft?
            payload[:metadata] ||= {}
            payload[:metadata][:draft] = true
          end

          cmd = command_utilities.build_command(command_name, payload)
          guard_evaluator_class = command_utilities.fetch_guard_evaluator_class(command_name)

          response = execute_command(cmd, guard_evaluator_class, skip_guards: !guards)

          update_read_model_with_revision_guard(response.event, payload, command_name) if response.success? 

          response
        end

        def command_response_class(cmd)
          cmd.is_a?(Yousty::Eventsourcing::CommandGroup) ? CommandGroupResponse : CommandResponse
        end

        # Sets the pending_update_since timestamp on the read model
        # This marks the read model as being in a pending update state
        # @raise [ActiveRecord::RecordNotUnique] if another process is already updating this aggregate
        def set_pending_update_state
          return unless read_model.respond_to?(:pending_update_since=)

          begin
            read_model.update_column(:pending_update_since, Time.current)
          rescue ActiveRecord::RecordNotUnique => e
            # Another process is already updating this aggregate
            # Let it retry through the normal retry mechanism
            raise PgEventstore::WrongExpectedRevisionError.new(
              revision: -1,
              expected_revision: -1,
              stream: { context: 'dummy', stream_name: "aggregate-#{read_model.id}", stream_id: read_model.id }
            ), "Another process is updating this aggregate (pending state conflict): #{e.message}"
          end
        end

        # Clears the pending_update_since timestamp on the read model
        # This marks the read model as no longer being in a pending update state
        def clear_pending_update_state
          return unless read_model.respond_to?(:pending_update_since=)

          read_model.update_column(:pending_update_since, nil)
        end
      end
    end
  end
end
