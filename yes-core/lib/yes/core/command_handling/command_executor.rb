# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling

      # Raised when multiple processes attempt to update the same aggregate concurrently
      # This error is thrown when the pending_update_since mechanism detects a conflict
      class ConcurrentUpdateError < Yes::Core::Error
        # Initializes a new ConcurrentUpdateError
        #
        # @param aggregate_class [Class] The aggregate class
        # @param aggregate_id [String] The ID of the aggregate being updated
        # @param original_error [Exception] The underlying database error
        def initialize(aggregate_class:, aggregate_id:, original_error: nil)
          message = build_error_message(aggregate_class, aggregate_id, original_error)
          
          super(message, extra: {
            aggregate_class: aggregate_class.name,
            aggregate_id: aggregate_id,
            context: aggregate_class.context,
            stream_name: aggregate_class.aggregate,
            original_error: original_error&.message
          })
        end

        private

        # Builds the error message
        #
        # @param aggregate_class [Class] The aggregate class
        # @param aggregate_id [String] The aggregate ID
        # @param original_error [Exception, nil] The underlying error if any
        # @return [String] The formatted error message
        def build_error_message(aggregate_class, aggregate_id, original_error)
          context = aggregate_class.context
          stream_name = aggregate_class.aggregate
          
          base_message = "Concurrent update detected for #{context}::#{stream_name} with ID #{aggregate_id}. " \
                        "Another process is currently updating this aggregate."
          
          if original_error
            "#{base_message} Original error: #{original_error.message}"
          else
            base_message
          end
        end
      end

      # Executes commands with retry logic and pending state management
      # Handles the core command execution including guard evaluation, event publishing,
      # and error handling with optimistic concurrency control
      #
      # @example
      #   executor = CommandExecutor.new(aggregate)
      #   response = executor.call(command, guard_evaluator_class)
      #
      class CommandExecutor
        MAX_RETRIES = 5

        # Initializes a new CommandExecutor
        #
        # @param aggregate [Yes::Core::Aggregate] The aggregate instance to execute commands for
        def initialize(aggregate)
          @aggregate = aggregate
          @read_model = aggregate.read_model if aggregate.class.read_model_enabled?
        end

        # Executes a command with retry logic and error handling
        #
        # @param cmd [Yes::Core::Command] The command to execute
        # @param command_name [Symbol] The name of the command being executed
        # @param guard_evaluator_class [Class] The guard evaluator class to process the command
        # @param skip_guards [Boolean] Whether to skip guard evaluation (default: false)
        # @return [Yousty::Eventsourcing::Stateless::CommandResponse] The command response
        def call(cmd, command_name, guard_evaluator_class, skip_guards: false)
          retries = 0

          begin
            evaluator = GuardRunner.new(aggregate).call(cmd, command_name, guard_evaluator_class, skip_guards:)

            set_pending_update_state if aggregate.class.read_model_enabled?

            begin
              event = EventPublisher.new(
                command: cmd,
                aggregate_data: EventPublisher::AggregateEventPublicationData.from_aggregate(aggregate),
                accessed_external_aggregates: evaluator&.accessed_external_aggregates || []
              ).call
            rescue StandardError => e
              clear_pending_update_state if aggregate.class.read_model_enabled?
              raise e
            end

            command_response_class(cmd).new(cmd:, event:)
          rescue PgEventstore::WrongExpectedRevisionError => e
            retries += 1
            clear_pending_update_state if aggregate.class.read_model_enabled?

            retries <= MAX_RETRIES ? retry : raise(e)
          rescue ConcurrentUpdateError => e
            retries += 1
            # Don't clear pending state - another process owns it
            retries <= MAX_RETRIES ? retry : raise(e)
          rescue GuardEvaluator::InvalidTransition,
                 GuardEvaluator::NoChangeTransition,
                 Yousty::Eventsourcing::Command::Invalid => e
            command_response_class(cmd).new(cmd: cmd, error: e, batch_id: cmd.batch_id)
          end
        end

        private

        attr_reader :aggregate, :read_model

        # Sets pending update state on read model
        #
        # @return [void]
        # @raise [ConcurrentUpdateError] If another process is already updating
        def set_pending_update_state
          return unless read_model

          begin
            read_model.update_column(:pending_update_since, Time.current)
          rescue ActiveRecord::StatementInvalid => e
            raise e unless e.message.include?('Concurrent pending update not allowed')

            raise ConcurrentUpdateError.new(
              aggregate_class: aggregate.class,
              aggregate_id: read_model.id,
              original_error: e
            )
          end
        end

        # Clears pending update state on read model
        #
        # @return [void]
        def clear_pending_update_state
          return unless read_model

          read_model.update_column(:pending_update_since, nil)
        end

        # Determines the appropriate response class for the command
        #
        # @param cmd [Yes::Core::Command] The command
        # @return [Class] CommandGroupResponse or CommandResponse class
        def command_response_class(cmd)
          if cmd.is_a?(Yousty::Eventsourcing::CommandGroup)
            Yousty::Eventsourcing::Stateless::CommandGroupResponse
          else
            Yes::Core::CommandResponse
          end
        end
      end
    end
  end
end