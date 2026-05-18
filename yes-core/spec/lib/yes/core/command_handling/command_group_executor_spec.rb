# frozen_string_literal: true

# Exercises the concurrency semantics of {CommandGroupExecutor}:
#
# - First sub-event publishes via {EventPublisher} so own-stream
#   `expected_revision` AND external-aggregate revision checks both fire.
# - Subsequent sub-events publish directly with `expected_revision: :any`.
# - `WrongExpectedRevisionError` raised by the first append propagates up to
#   the outer rescue and retries the whole flow — guards re-evaluate against
#   a fresh snapshot.
RSpec.describe Yes::Core::CommandHandling::CommandGroupExecutor, integration: true do
  let(:aggregate_class) { Test::PersonalInfo::Aggregate }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:aggregate) { aggregate_class.new(aggregate_id) }

  let(:valid_payload) do
    {
      first_name: 'Ada',
      last_name: 'Lovelace',
      email: 'ada@example.com',
      birth_date: '1815-12-10'
    }
  end

  describe 'concurrency semantics' do
    context 'first sub-event uses EventPublisher' do
      it 'routes the first sub-event through EventPublisher with accessed_external_aggregates' do
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_call_original

        aggregate.update_personal_info_group(**valid_payload)

        # pg_eventstore may retry the `multiple` block on MissingPartitions
        # (when event-type partitions don't exist yet), causing multiple
        # EventPublisher.new invocations within one logical group call.
        # Either way, every invocation carries the accessed_external_aggregates
        # keyword — that's the contract we care about.
        expect(Yes::Core::CommandHandling::EventPublisher).to have_received(:new).
          with(hash_including(accessed_external_aggregates: [])).
          at_least(:once)
      end
    end

    context 'subsequent sub-events use direct append with :any' do
      it 'sequences the 2nd and 3rd events on top of the first within the same transaction' do
        response = aggregate.update_personal_info_group(**valid_payload)

        revisions = response.events.map(&:stream_revision)
        expect(revisions).to eq([0, 1, 2])
      end
    end

    context 'when the own stream advances between guard evaluation and publish' do
      it 'retries on WrongExpectedRevisionError and eventually succeeds' do
        call_count = 0
        original_new = Yes::Core::CommandHandling::EventPublisher.method(:new)

        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new) do |**kwargs|
          call_count += 1
          publisher = original_new.call(**kwargs)
          if call_count == 1
            # First attempt: simulate a concurrent writer having advanced
            # the stream between guard eval and our publish.
            allow(publisher).to receive(:call).and_raise(
              PgEventstore::WrongExpectedRevisionError.new(
                revision: 2,
                expected_revision: :no_stream,
                stream: PgEventstore::Stream.new(
                  context: 'Test', stream_name: 'PersonalInfo', stream_id: aggregate_id
                )
              )
            )
          end
          publisher
        end

        response = aggregate.update_personal_info_group(**valid_payload)

        aggregate_failures do
          expect(call_count).to be >= 2
          expect(response).to be_success
          expect(response.events.size).to eq(3)
        end
      end
    end

    context 'when retries exceed MAX_RETRIES' do
      it 'eventually re-raises the WrongExpectedRevisionError' do
        always_failing = instance_double(Yes::Core::CommandHandling::EventPublisher)
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_return(always_failing)
        allow(always_failing).to receive(:call).and_raise(
          PgEventstore::WrongExpectedRevisionError.new(
            revision: 99,
            expected_revision: :no_stream,
            stream: PgEventstore::Stream.new(
              context: 'Test', stream_name: 'PersonalInfo', stream_id: aggregate_id
            )
          )
        )

        expect { aggregate.update_personal_info_group(**valid_payload) }.
          to raise_error(PgEventstore::WrongExpectedRevisionError)
      end
    end

    context 'guards re-evaluate on retry' do
      it 're-runs the group guard each time the executor retries' do
        # Count how many GuardEvaluator instances get constructed. Each
        # retry of {CommandGroupExecutor#call} re-enters the begin block,
        # which re-creates a new GuardEvaluator via GuardRunner. Multiple
        # constructions proves multiple guard evaluations.
        guard_evaluator_class = Yes::Core.configuration.aggregate_class(
          'Test', 'PersonalInfo', :update_personal_info_group, :command_group_guard_evaluator
        )
        original_new = guard_evaluator_class.method(:new)
        evaluator_count = 0
        allow(guard_evaluator_class).to receive(:new) do |**kwargs|
          evaluator_count += 1
          original_new.call(**kwargs)
        end

        # Force the first two EventPublisher attempts to raise, then succeed.
        call_count = 0
        original_pub_new = Yes::Core::CommandHandling::EventPublisher.method(:new)
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new) do |**kwargs|
          call_count += 1
          publisher = original_pub_new.call(**kwargs)
          if call_count <= 2
            allow(publisher).to receive(:call).and_raise(
              PgEventstore::WrongExpectedRevisionError.new(
                revision: 0,
                expected_revision: :no_stream,
                stream: PgEventstore::Stream.new(
                  context: 'Test', stream_name: 'PersonalInfo', stream_id: aggregate_id
                )
              )
            )
          end
          publisher
        end

        aggregate.update_personal_info_group(**valid_payload)

        # Original attempt + 2 retries = 3 GuardEvaluator constructions (minimum).
        expect(evaluator_count).to be >= 3
      end
    end
  end
end
