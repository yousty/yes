# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::ReadModelRevisionGuard do
  subject(:guard) { described_class.new(read_model, expected_revision) }

  let(:read_model) { instance_double('ReadModel', revision: current_revision) }
  let(:current_revision) { 10 }
  let(:expected_revision) { 11 }
  let(:logger) { instance_double('Logger', info: nil, error: nil, debug: nil, debug?: false) }

  before do
    allow(read_model).to receive(:reload).and_return(read_model)
    # Stub Rails.logger to use our test double
    allow(Rails).to receive(:logger).and_return(logger) if defined?(Rails)
  end

  describe '.call' do
    it 'delegates to instance method' do
      block_called = false
      block = -> { block_called = true }

      described_class.call(read_model, expected_revision, &block)

      expect(block_called).to be true
    end
  end

  describe '#call' do
    context 'when revision matches on first attempt' do
      it 'executes the block immediately' do
        block_called = false

        result = guard.call do
          block_called = true
          'success'
        end

        aggregate_failures do
          expect(block_called).to be true
          expect(result).to eq('success')
          expect(read_model).not_to have_received(:reload)
        end
      end

      it 'does not log when successful on first attempt' do
        guard.call { 'success' }

        expect(logger).not_to have_received(:info)
      end
    end

    context 'when revision does not match initially' do
      let(:expected_revision) { 15 }

      before do
        allow(guard).to receive(:sleep)
      end

      context 'and matches after retry' do
        before do
          # Each iteration calls revision twice: in check_revision_status! and revision_matches?
          # Iteration 1: 10, 10 (no match, retry)
          # Iteration 2: 10, 10 (no match, retry)
          # Iteration 3: 14, 14 (match!)
          revision_sequence = [10, 10, 10, 10, 14, 14]
          revision_index = 0

          allow(read_model).to receive(:revision) do
            current_value = revision_sequence[revision_index]
            revision_index += 1 if revision_index < revision_sequence.length - 1
            current_value
          end
        end

        it 'retries and executes the block when revision matches' do
          block_called = false

          result = guard.call do
            block_called = true
            'success'
          end

          aggregate_failures do
            expect(block_called).to be true
            expect(result).to eq('success')
            expect(read_model).to have_received(:reload).twice
            expect(guard).to have_received(:sleep).twice
          end
        end

        it 'logs success when revision matches after retries' do
          guard.call { 'success' }

          expect(logger).to have_received(:info).with(/succeeded after 2 attempts/)
        end

        it 'uses exponential backoff with jitter for sleep times' do
          guard.call { 'success' }

          aggregate_failures do
            # First sleep should be around 0.1s ± 10%
            expect(guard).to have_received(:sleep).with(a_value_between(0.09, 0.11)).ordered
            # Second sleep should be around 0.2s ± 10%
            expect(guard).to have_received(:sleep).with(a_value_between(0.18, 0.22)).ordered
          end
        end
      end

      context 'and never matches' do
        it 'raises RevisionMismatchError after maximum retries' do
          expect do
            guard.call { 'should not execute' }
          end.to raise_error(
            described_class::RevisionMismatchError,
            /Revision mismatch after 7 attempts/
          )
        end

        it 'logs error when failing after maximum retries' do
          expect { guard.call { 'should not execute' } }.to raise_error(described_class::RevisionMismatchError)

          expect(logger).to have_received(:error).with(/failed after 7 attempts/)
        end

        it 'includes current and expected revisions in error message' do
          expect do
            guard.call { 'should not execute' }
          end.to raise_error(
            described_class::RevisionMismatchError,
            /Expected revision 15, but read model has revision 10/
          )
        end

        it 'performs exactly MAX_RETRIES attempts' do
          expect { guard.call { 'should not execute' } }.to raise_error(described_class::RevisionMismatchError)

          expect(read_model).to have_received(:reload).exactly(6).times
        end

        it 'respects maximum sleep time cap' do
          # Even with many retries, sleep time should never exceed MAX_SLEEP_TIME
          expect { guard.call { 'should not execute' } }.to raise_error(described_class::RevisionMismatchError)

          aggregate_failures do
            # The last few sleeps should be capped at MAX_SLEEP_TIME (5.0) ± jitter
            expect(guard).to have_received(:sleep).with(a_value_between(0.09, 0.11)).ordered  # ~0.1
            expect(guard).to have_received(:sleep).with(a_value_between(0.18, 0.22)).ordered  # ~0.2
            expect(guard).to have_received(:sleep).with(a_value_between(0.36, 0.44)).ordered  # ~0.4
            expect(guard).to have_received(:sleep).with(a_value_between(0.72, 0.88)).ordered  # ~0.8
            expect(guard).to have_received(:sleep).with(a_value_between(1.44, 1.76)).ordered  # ~1.6
            expect(guard).to have_received(:sleep).with(a_value_between(2.88, 3.52)).ordered  # ~3.2
          end
        end
      end

      context 'with timeout' do
        before do
          # Simulate timeout by stubbing Time.current
          start_time = Time.current
          allow(Time).to receive(:current).and_return(
            start_time,
            start_time + 31.seconds
          )
        end

        it 'raises TimeoutError when timeout is exceeded' do
          expect do
            guard.call { 'should not execute' }
          end.to raise_error(
            described_class::TimeoutError,
            /Timeout after 31.0s waiting for revision 15/
          )
        end
      end

      context 'with many retries to test sleep time cap' do
        before do
          # Stub calculate_sleep_time to test the cap behavior
          allow(guard).to receive(:calculate_sleep_time).and_call_original
        end

        it 'caps sleep time at MAX_SLEEP_TIME even for high attempt numbers' do
          # Test that the 7th attempt would be capped
          sleep_time = guard.send(:calculate_sleep_time, 7)

          aggregate_failures do
            # 7th attempt would be 0.1 * 2^6 = 6.4s without cap, but should be capped at 5.0
            expect(sleep_time).to be <= described_class::MAX_SLEEP_TIME
            expect(sleep_time).to be >= described_class::MAX_SLEEP_TIME * 0.9 # Account for negative jitter
          end
        end
      end
    end

    context 'when read model revision is higher than expected' do
      let(:current_revision) { 20 }
      let(:expected_revision) { 15 }

      before do
        allow(guard).to receive(:sleep)
      end

      it 'raises RevisionAlreadyAppliedError' do
        expect do
          guard.call { 'should not execute' }
        end.to raise_error(
          described_class::RevisionAlreadyAppliedError,
          /Expected revision 15 but read model already at revision 20/
        )
      end
    end

    context 'when read model revision equals expected revision' do
      let(:current_revision) { 15 }
      let(:expected_revision) { 15 }

      it 'raises RevisionAlreadyAppliedError' do
        expect do
          guard.call { 'should not execute' }
        end.to raise_error(
          described_class::RevisionAlreadyAppliedError,
          /Expected revision 15 but read model already at revision 15/
        )
      end
    end

    context 'when block raises an error' do
      it 'propagates the error' do
        custom_error = Class.new(StandardError)

        expect do
          guard.call { raise custom_error, 'Something went wrong' }
        end.to raise_error(custom_error, 'Something went wrong')
      end
    end

    context 'with debug logging enabled' do
      before do
        allow(logger).to receive(:debug?).and_return(true)

        revision_sequence = [10, 10, 10, 10, 10, 10, 14, 14]
        revision_index = 0

        allow(read_model).to receive(:revision) do
          current_value = revision_sequence[revision_index]
          revision_index += 1 if revision_index < revision_sequence.length - 1
          current_value
        end

        # Capture debug messages
        @debug_messages = []
        allow(logger).to receive(:debug) do |&block|
          @debug_messages << block.call if block
        end
      end

      let(:expected_revision) { 15 }

      it 'logs retry attempts when debug is enabled' do
        guard.call { 'success' }

        expect(@debug_messages.size).to eq(2)
        expect(@debug_messages[0]).to match(%r{retry 1/6})
        expect(@debug_messages[1]).to match(%r{retry 2/6})
      end
    end
  end

  describe 'constants' do
    it 'has MAX_RETRIES set to 6' do
      expect(described_class::MAX_RETRIES).to eq(6)
    end

    it 'has BASE_SLEEP_TIME set to 0.1' do
      expect(described_class::BASE_SLEEP_TIME).to eq(0.1)
    end

    it 'has MAX_SLEEP_TIME set to 5.0' do
      expect(described_class::MAX_SLEEP_TIME).to eq(5.0)
    end

    it 'has JITTER_FACTOR set to 0.1' do
      expect(described_class::JITTER_FACTOR).to eq(0.1)
    end

    it 'has TIMEOUT set to 30' do
      expect(described_class::TIMEOUT).to eq(30)
    end
  end

  describe '#calculate_sleep_time' do
    it 'adds jitter to prevent thundering herd' do
      # Run multiple times to verify randomness
      sleep_times = Array.new(10) { guard.send(:calculate_sleep_time, 1) }

      aggregate_failures do
        # All should be within ±10% of base time (0.1s)
        expect(sleep_times).to all(be_between(0.09, 0.11))
        # But they should not all be the same (jitter is working)
        expect(sleep_times.uniq.size).to be > 1
      end
    end
  end

  describe 'with custom revision column' do
    subject(:guard) { described_class.new(read_model, expected_revision, revision_column: :users_revision) }

    let(:read_model) { instance_double('ReadModel', users_revision: current_revision, revision: nil) }

    context 'when using a custom revision column' do
      it 'uses the specified column for revision checks' do
        block_called = false

        result = guard.call do
          block_called = true
          'success'
        end

        aggregate_failures do
          expect(block_called).to be true
          expect(result).to eq('success')
          expect(read_model).to have_received(:users_revision).at_least(:once)
          expect(read_model).not_to have_received(:revision)
        end
      end

      context 'when revision mismatch occurs' do
        let(:expected_revision) { 15 }

        it 'includes the custom column name in error message' do
          expect do
            guard.call { 'should not execute' }
          end.to raise_error(
            described_class::RevisionMismatchError,
            /Expected: read_model.users_revision \(10\) \+ 1 = 15/
          )
        end
      end
    end

    context 'when using .call class method with custom column' do
      it 'passes the revision_column parameter correctly' do
        block_called = false

        result = described_class.call(read_model, expected_revision, revision_column: :users_revision) do
          block_called = true
          'success'
        end

        aggregate_failures do
          expect(block_called).to be true
          expect(result).to eq('success')
          expect(read_model).to have_received(:users_revision).at_least(:once)
        end
      end
    end
  end
end
