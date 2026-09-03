# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::CommandExecutor do
  subject(:executor) { described_class.new(aggregate) }

  let(:aggregate_id) { SecureRandom.uuid }
  let(:user_id) { SecureRandom.uuid }
  let!(:read_model) { TestUser.create!(id: aggregate_id, name: 'John') }
  let(:aggregate) { Test::User::Aggregate.new(aggregate_id) }

  # Makes every EventPublisher raise `error` for the first `failing_attempts` calls and
  # return a published event afterwards, without touching the eventstore.
  def stub_event_publisher(failing_attempts:, error:)
    attempts = 0
    allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_wrap_original do |original, **kwargs|
      original.call(**kwargs).tap do |publisher|
        allow(publisher).to receive(:call) do
          attempts += 1
          raise error if attempts <= failing_attempts

          Yes::Core::Event.new(id: SecureRandom.uuid, type: 'Test::User::NameChanged', data: { 'name' => 'Jane' })
        end
      end
    end
  end

  describe '#call' do
    subject { executor.call(command, command_name, guard_evaluator_class, skip_guards:) }

    let(:command_name) { :change_name }
    let(:guard_evaluator_class) { Test::User::Commands::ChangeName::GuardEvaluator }
    let(:skip_guards) { false }

    let(:command) do
      Test::User::Commands::ChangeName::Command.new(
        name: 'Jane',
        user_id:
      )
    end

    context 'when successful' do
      it 'successfully executes when value changes' do
        result = subject

        aggregate_failures do
          expect(result).to be_a(Yes::Core::Commands::Response)
          expect(result.error).to be_nil
          expect(result.event).to be_present
        end
      end
    end

    context 'when guard fails' do
      let(:command) do
        Test::User::Commands::ChangeName::Command.new(
          name: 'John', # Same as current value
          user_id:
        )
      end

      it 'returns error when value does not change' do
        # The no_change guard is automatically added to change commands
        result = subject

        aggregate_failures do
          expect(result).to be_a(Yes::Core::Commands::Response)
          expect(result.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition)
          expect(result.error.message).to include('no_change')
          expect(result.event).to be_nil
        end
      end
    end

    context 'when guards are skipped' do
      let(:command) do
        Test::User::Commands::ChangeName::Command.new(
          name: 'John', # Same value - would normally fail no_change guard
          user_id:
        )
      end

      let(:skip_guards) { true }

      it 'executes successfully even when guard would fail' do
        result = subject

        aggregate_failures do
          expect(result).to be_a(Yes::Core::Commands::Response)
          expect(result.error).to be_nil
          expect(result.event).to be_present
        end
      end
    end

    context 'with concurrent updates' do
      context 'when another process is updating the same record' do
        before do
          read_model.update_column(:pending_update_since, 1.second.ago)
        end

        it 'raises ConcurrentUpdateError' do
          expect { subject }.to raise_error(Yes::Core::CommandHandling::ConcurrentUpdateError)
        end
      end

      context 'when event store has revision conflict' do
        let(:revision_error) do
          PgEventstore::WrongExpectedRevisionError.new(
            revision: 1, expected_revision: 2, stream: {}, verdict: :unmatched_stream_revision
          )
        end

        before do
          call_count = 0
          allow(PgEventstore.client).to receive(:append_to_stream) do
            call_count += 1
            raise revision_error if call_count <= 2

            # Return event on success
            Yes::Core::Event.new(
              id: SecureRandom.uuid,
              type: 'Test::User::NameChanged',
              data: { 'name' => 'Jane' }
            )
          end
        end

        it 'retries and succeeds' do
          result = subject

          aggregate_failures do
            expect(result).to be_a(Yes::Core::Commands::Response)
            expect(result.error).to be_nil
            expect(result.event).to be_present
          end
        end
      end

      context 'when another service advanced the stream and the read model still lags behind' do
        let(:revision_error) do
          PgEventstore::WrongExpectedRevisionError.new(
            revision: 6, expected_revision: 5, stream: {}, verdict: :unmatched_stream_revision
          )
        end

        before do
          read_model.update_column(:revision, 5)
          allow(executor).to receive(:sleep)
          allow(Yes::Core::CommandHandling::RevisionConflictBackoff).to receive(:rand).and_return(0.5)
          stub_event_publisher(failing_attempts: 2, error: revision_error)
        end

        it 'backs off between the retries until the read model has a chance to catch up' do
          result = subject

          aggregate_failures do
            expect(result.error).to be_nil
            expect(executor).to have_received(:sleep).with(0.01).ordered
            expect(executor).to have_received(:sleep).with(0.02).ordered
            expect(executor).to have_received(:sleep).twice
          end
        end
      end

      context 'when the read model already reflects the revision the stream reports' do
        let(:revision_error) do
          PgEventstore::WrongExpectedRevisionError.new(
            revision: 5, expected_revision: 4, stream: {}, verdict: :unmatched_stream_revision
          )
        end

        before do
          read_model.update_column(:revision, 5)
          allow(executor).to receive(:sleep)
          stub_event_publisher(failing_attempts: 2, error: revision_error)
        end

        it 'retries without waiting' do
          result = subject

          aggregate_failures do
            expect(result.error).to be_nil
            expect(executor).not_to have_received(:sleep)
          end
        end
      end

      context 'when event store fails persistently' do
        let(:revision_error) do
          PgEventstore::WrongExpectedRevisionError.new(
            revision: 1, expected_revision: 2, stream: {}, verdict: :unmatched_stream_revision
          )
        end

        before { allow(executor).to receive(:sleep) } # the read model never catches up here, so every retry would wait for real

        it 'raises error after MAX_RETRIES' do
          call_count = 0
          allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_wrap_original do |original, **kwargs|
            publisher = original.call(**kwargs)
            allow(publisher).to receive(:call) do
              call_count += 1
              raise revision_error
            end
            publisher
          end

          expect { subject }.to raise_error(revision_error)

          # Verify it attempted 11 times (initial + 10 retries, MAX_RETRIES = 10)
          expect(call_count).to eq(11)
        end
      end

      context 'when ConcurrentUpdateError occurs repeatedly' do
        before do
          allow(aggregate).to receive(:read_model).and_return(read_model)
          allow(read_model).to receive(:update_column) do |column, value|
            raise ActiveRecord::StatementInvalid, 'Concurrent pending update not allowed' if column == :pending_update_since && value.present?

            read_model.class.where(id: read_model.id).update_all(column => value)
          end
        end

        it 'attempts inline recovery after INLINE_RECOVERY_RETRY_THRESHOLD retries' do
          expect(Yes::Core::CommandHandling::ReadModelRecoveryService).
            to receive(:attempt_inline_recovery).
            at_least(:once).
            and_return(false)

          expect { subject }.to raise_error(Yes::Core::CommandHandling::ConcurrentUpdateError)
        end

        it 'sleeps with exponential backoff between retries' do
          allow(Yes::Core::CommandHandling::ReadModelRecoveryService).
            to receive(:attempt_inline_recovery).
            and_return(false)

          expect(executor).to receive(:sleep).at_least(:once)

          expect { subject }.to raise_error(Yes::Core::CommandHandling::ConcurrentUpdateError)
        end

        it 'reloads read model after inline recovery attempt' do
          allow(Yes::Core::CommandHandling::ReadModelRecoveryService).
            to receive(:attempt_inline_recovery).
            and_return(false)

          expect(read_model).to receive(:reload).at_least(:once)

          expect { subject }.to raise_error(Yes::Core::CommandHandling::ConcurrentUpdateError)
        end
      end
    end
  end
end
