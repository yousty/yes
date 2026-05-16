# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Low-level executor for command groups.
      #
      # Mirrors {CommandExecutor}, with two key differences:
      #
      # 1. Sub-command events publish inside a single
      #    `PgEventstore.client.multiple` block, so either all events commit
      #    atomically or none do.
      # 2. Read-model updates run AFTER the eventstore commit succeeds, in
      #    declaration order, so a rolled-back transaction never leaves the
      #    read model ahead of the stream.
      #
      # Only the group's own guards run here — sub-command guards are
      # bypassed by design (see plan: "Decisions made up front").
      class CommandGroupExecutor
        MAX_RETRIES = 10
        INLINE_RECOVERY_RETRY_THRESHOLD = 5

        # @param aggregate [Yes::Core::Aggregate]
        def initialize(aggregate)
          @aggregate = aggregate
          @read_model = aggregate.read_model if aggregate.class.read_model_enabled?
        end

        # @param cmd [Yes::Core::Commands::CommandGroup]
        # @param group_name [Symbol]
        # @param guard_evaluator_class [Class]
        # @param skip_guards [Boolean]
        # @return [Yes::Core::Commands::CommandGroupResponse]
        def call(cmd, group_name, guard_evaluator_class, skip_guards: false)
          retries = 0

          begin
            evaluator = GuardRunner.new(aggregate).call(cmd, group_name, guard_evaluator_class, skip_guards:)
            external_aggregates = evaluator&.accessed_external_aggregates || []

            set_pending_update_state if aggregate.class.read_model_enabled?

            events = publish_events(cmd, external_aggregates)
            apply_read_model_updates(cmd, events) if aggregate.class.read_model_enabled?

            Yes::Core::Commands::CommandGroupResponse.new(cmd:, events:)
          rescue PgEventstore::WrongExpectedRevisionError => e
            retries += 1
            clear_pending_update_state if aggregate.class.read_model_enabled?
            retries <= MAX_RETRIES ? retry : raise(e)
          rescue ConcurrentUpdateError => e
            retries += 1
            sleep([0.01 * (2**(retries - 1)), 1.0].min) if retries <= MAX_RETRIES

            if aggregate.class.read_model_enabled? && retries >= INLINE_RECOVERY_RETRY_THRESHOLD
              ReadModelRecoveryService.attempt_inline_recovery(read_model, aggregate: aggregate)
              read_model.reload
            end

            retries <= MAX_RETRIES ? retry : raise(e)
          rescue GuardEvaluator::InvalidTransition,
                 GuardEvaluator::NoChangeTransition,
                 Yes::Core::Command::Invalid => e
            clear_pending_update_state if aggregate.class.read_model_enabled?
            Yes::Core::Commands::CommandGroupResponse.new(cmd:, error: e)
          end
        end

        private

        attr_reader :aggregate, :read_model

        # Publishes each sub-command's event inside a single eventstore
        # transaction. If publishing fails partway through, the whole
        # transaction rolls back via PgEventstore::Commands::Multiple.
        #
        # The FIRST sub-event goes through {EventPublisher}, which performs
        # two concurrency checks that bring group flow up to parity with the
        # per-command flow:
        #
        #   1. **Own-stream optimistic locking** — `expected_revision` is
        #      derived from `read_model.revision` (or the latest stream
        #      revision when read models are disabled), so a concurrent
        #      writer that committed to the same stream between guard
        #      evaluation and publish raises `WrongExpectedRevisionError`,
        #      which the outer rescue retries and re-runs guards against the
        #      fresh state.
        #   2. **External-aggregate revision verification** —
        #      `verify_external_revisions!` checks every aggregate that the
        #      group's guard block touched (tracked by
        #      {AggregateTracker} via {GuardEvaluator}#method_missing and
        #      {PayloadProxy}#resolve_aggregate). A drifted external stream
        #      raises `WrongExpectedRevisionError`, same retry path.
        #
        # SUBSEQUENT sub-events go through the direct append path with
        # `expected_revision: :any`. They don't need their own optimistic
        # check because:
        #   - they're inside the same `multiple` block / PG transaction at
        #     serializable isolation,
        #   - any concurrent writer that committed during this transaction
        #     would have failed step 1 above (or surfaced as
        #     `PG::TRSerializationFailure`, which pg_eventstore retries
        #     transparently for the whole block),
        #   - their stream revisions chain naturally onto the first append
        #     because each `Append` reads `stream_revision` fresh inside the
        #     same transaction and sees the previous appends.
        #
        # We assign `published` from inside the block so pg_eventstore's
        # internal retry on `MissingPartitions` / serialization failures
        # doesn't accumulate duplicate event entries across retries.
        #
        # Pending-state cleanup is handled exclusively by the outer rescue
        # chain in {#call} so that `ConcurrentUpdateError`'s "another process
        # owns it" semantics are preserved.
        #
        # @param cmd [Yes::Core::Commands::CommandGroup]
        # @param external_aggregates [Array<Hash>] aggregates accessed during
        #   guard evaluation; verified against their current stream revisions
        #   at publish time
        # @return [Array<PgEventstore::Event>]
        def publish_events(cmd, external_aggregates)
          published = nil
          PgEventstore.client.multiple do
            published = cmd.commands.each_with_index.map do |sub_cmd, index|
              if index.zero?
                publish_first_sub_event(sub_cmd, external_aggregates)
              else
                publish_subsequent_sub_event(sub_cmd)
              end
            end
          end
          published
        end

        # Publishes the first sub-event via {EventPublisher}, getting both
        # own-stream optimistic locking and external-aggregate revision
        # verification for free.
        #
        # @param sub_cmd [Yes::Core::Command]
        # @param external_aggregates [Array<Hash>]
        # @return [PgEventstore::Event]
        def publish_first_sub_event(sub_cmd, external_aggregates)
          EventPublisher.new(
            command: sub_cmd,
            aggregate_data: EventPublisher::AggregateEventPublicationData.from_aggregate(aggregate),
            accessed_external_aggregates: external_aggregates
          ).call
        end

        # Publishes a subsequent (2nd+) sub-event with `expected_revision: :any`.
        # Atomicity and revision sequencing are guaranteed by the surrounding
        # `multiple` block — see {#publish_events} docstring for details.
        #
        # @param sub_cmd [Yes::Core::Command]
        # @return [PgEventstore::Event]
        def publish_subsequent_sub_event(sub_cmd)
          utils = Utils::CommandUtils.new(
            context: aggregate.class.context,
            aggregate: aggregate.class.aggregate,
            aggregate_id: aggregate.id
          )
          sub_command_name = sub_cmd.class.name.split('::')[-2].underscore.to_sym
          event = utils.build_event(
            command_name: sub_command_name,
            payload: sub_cmd.payload,
            metadata: sub_event_metadata(sub_cmd)
          )

          PgEventstore.client.append_to_stream(
            utils.build_stream(metadata: sub_cmd.metadata || {}),
            event,
            options: { expected_revision: :any }
          )
        end

        def sub_event_metadata(sub_cmd)
          meta = {}
          meta['origin'] = sub_cmd.origin if sub_cmd.origin.present?
          meta['batch_id'] = sub_cmd.batch_id if sub_cmd.batch_id.present?
          meta['yes-dsl'] = true
          meta.merge!(sub_cmd.metadata) if sub_cmd.metadata.present?
          meta.merge!(sub_cmd.transaction.for_eventstore_metadata) if sub_cmd.transaction
          meta.deep_transform_keys(&:to_s)
        end

        # Applies read-model updates for each (sub_cmd, event) pair in
        # declaration order, so each sub-command's state-updater sees the
        # state produced by the previous one.
        #
        # Intentionally NOT wrapped in an outer `ActiveRecord::Base.transaction`:
        # if the third sub-command's read-model update raises after the first
        # two succeed, the read model is left half-applied while the
        # eventstore stream is fully committed. This matches today's behaviour
        # for single commands (where any read-model failure after the event
        # publishes leaves the read model behind the stream) and is healed by
        # the standard event-replay/recovery path. An outer AR transaction is
        # tracked as a follow-up — see plan "Decision 2".
        #
        # @param cmd [Yes::Core::Commands::CommandGroup]
        # @param events [Array<PgEventstore::Event>]
        # @return [void]
        def apply_read_model_updates(cmd, events)
          cmd.commands.zip(events, cmd.class.sub_command_names).each do |sub_cmd, event, sub_name|
            ReadModelUpdater.new(aggregate).call(event, sub_cmd.payload, sub_name)
          end
        end

        # @see CommandExecutor#set_pending_update_state
        def set_pending_update_state
          return unless read_model

          begin
            ActiveRecord::Base.transaction(requires_new: true) do
              read_model.update_column(:pending_update_since, Time.current)
            end
          rescue ActiveRecord::StatementInvalid => e
            raise e unless e.message.include?('Concurrent pending update not allowed')

            raise ConcurrentUpdateError.new(
              aggregate_class: aggregate.class,
              aggregate_id: read_model.id,
              original_error: e
            )
          end
        end

        def clear_pending_update_state
          return unless read_model

          read_model.update_column(:pending_update_since, nil)
        end
      end
    end
  end
end
