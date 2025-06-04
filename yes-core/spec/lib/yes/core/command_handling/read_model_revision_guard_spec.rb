# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::ReadModelRevisionGuard do
  subject(:guard) { described_class.new(read_model, expected_revision) }

  let(:read_model) { instance_double('ReadModel', revision: current_revision) }
  let(:current_revision) { 10 }
  let(:expected_revision) { 11 }
  let(:retrier) { instance_double(Yes::Core::Utils::ExponentialRetrier) }

  before do
    allow(read_model).to receive(:reload).and_return(read_model)
    allow(Yes::Core::Utils::ExponentialRetrier).to receive(:new).and_return(retrier)
  end

  describe '.call' do
    before do
      allow(retrier).to receive(:call).and_yield
    end

    it 'delegates to instance method' do
      block_called = false
      result = described_class.call(read_model, expected_revision) do
        block_called = true
        'success'
      end

      aggregate_failures do
        expect(block_called).to be true
        expect(result).to eq('success')
      end
    end
  end

  describe '#call' do
    context 'when revision matches' do
      before do
        allow(retrier).to receive(:call).and_yield
      end

      it 'executes the block and returns result' do
        block_called = false

        result = guard.call do
          block_called = true
          'success'
        end

        aggregate_failures do
          expect(block_called).to be true
          expect(result).to eq('success')
        end
      end

      it 'creates retrier with correct configuration' do
        guard.call { 'success' }

        expect(Yes::Core::Utils::ExponentialRetrier).to have_received(:new).with(
          max_retries: 6,
          base_sleep_time: 0.1,
          max_sleep_time: 5.0,
          jitter_factor: 0.1,
          timeout: 30,
          logger: an_instance_of(described_class::ContextualLogger)
        )
      end

      it 'passes correct parameters to retrier' do
        guard.call { 'success' }

        expect(retrier).to have_received(:call).with(
          condition_check: an_instance_of(Proc),
          failure_message: an_instance_of(String),
          timeout_message: an_instance_of(String)
        )
      end
    end

    context 'when retrier raises RetryFailedError' do
      before do
        allow(retrier).to receive(:call).and_raise(
          Yes::Core::Utils::ExponentialRetrier::RetryFailedError, 'Retrier failed'
        )
      end

      it 'converts to RevisionMismatchError' do
        expect do
          guard.call { 'should not execute' }
        end.to raise_error(
          described_class::RevisionMismatchError,
          'Retrier failed'
        )
      end
    end

    context 'when retrier raises TimeoutError' do
      before do
        allow(retrier).to receive(:call).and_raise(
          Yes::Core::Utils::ExponentialRetrier::TimeoutError, 'Timeout occurred'
        )
      end

      it 'converts to guard TimeoutError' do
        expect do
          guard.call { 'should not execute' }
        end.to raise_error(
          described_class::TimeoutError,
          'Timeout occurred'
        )
      end
    end

    context 'when read model revision is higher than expected' do
      let(:current_revision) { 20 }
      let(:expected_revision) { 15 }

      before do
        allow(retrier).to receive(:call) do |condition_check:, **|
          condition_check.call
        end
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

      before do
        allow(retrier).to receive(:call) do |condition_check:, **|
          condition_check.call
        end
      end

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
      before do
        allow(retrier).to receive(:call).and_yield
      end

      it 'propagates the error' do
        custom_error = Class.new(StandardError)

        expect do
          guard.call { raise custom_error, 'Something went wrong' }
        end.to raise_error(custom_error, 'Something went wrong')
      end
    end
  end

  describe '#check_revision_and_return_match_status' do
    it 'reloads read model and checks revision match' do
      result = guard.send(:check_revision_and_return_match_status)

      aggregate_failures do
        expect(read_model).to have_received(:reload)
        expect(result).to be true
      end
    end

    context 'when revision does not match' do
      let(:expected_revision) { 15 }

      it 'returns false' do
        result = guard.send(:check_revision_and_return_match_status)

        expect(result).to be false
      end
    end

    context 'when revision is already applied' do
      let(:current_revision) { 15 }
      let(:expected_revision) { 10 }

      it 'raises RevisionAlreadyAppliedError' do
        expect do
          guard.send(:check_revision_and_return_match_status)
        end.to raise_error(described_class::RevisionAlreadyAppliedError)
      end
    end
  end

  describe '#revision_matches?' do
    context 'when current revision + 1 equals expected revision' do
      it 'returns true' do
        expect(guard.send(:revision_matches?)).to be true
      end
    end

    context 'when revisions do not match' do
      let(:expected_revision) { 15 }

      it 'returns false' do
        expect(guard.send(:revision_matches?)).to be false
      end
    end
  end

  describe 'error messages' do
    let(:expected_revision) { 15 }

    it 'generates detailed revision mismatch message' do
      message = guard.send(:revision_mismatch_message)

      expect(message).to eq(
        'Revision mismatch. ' \
        'Expected revision 15, but read model has revision 10. ' \
        'Expected: read_model.revision (10) + 1 = 15'
      )
    end

    it 'generates timeout message with revision context' do
      message = guard.send(:timeout_message)

      expect(message).to eq(
        'Timeout waiting for revision 15. Current revision: 10'
      )
    end
  end

  describe 'with custom revision column' do
    subject(:guard) { described_class.new(read_model, expected_revision, revision_column: :users_revision) }

    let(:read_model) { instance_double('ReadModel', users_revision: current_revision, revision: nil) }

    before do
      allow(retrier).to receive(:call).and_yield
    end

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
        message = guard.send(:revision_mismatch_message)

        expect(message).to include('read_model.users_revision (10) + 1 = 15')
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

  describe 'ContextualLogger' do
    let(:base_logger) { instance_double('Logger', info: nil, error: nil, debug: nil, debug?: false) }
    let(:contextual_logger) { described_class::ContextualLogger.new(base_logger, guard) }

    describe '#info' do
      it 'adds revision context to info messages' do
        contextual_logger.info('Test message')

        expect(base_logger).to have_received(:info).with('Test message for revision 11')
      end

      context 'when base logger is nil' do
        let(:base_logger) { nil }

        it 'does not raise error' do
          expect { contextual_logger.info('Test message') }.not_to raise_error
        end
      end
    end

    describe '#error' do
      it 'adds revision and current revision context to error messages' do
        contextual_logger.error('Test error')

        expect(base_logger).to have_received(:error).with(
          'Test error for revision 11. Current revision: 10'
        )
      end
    end

    describe '#debug' do
      context 'when debug is enabled' do
        before do
          allow(base_logger).to receive(:debug?).and_return(true)
        end

        it 'adds revision context to debug messages' do
          contextual_logger.debug('Test debug')

          expect(base_logger).to have_received(:debug).with(
            'Test debug for revision 11 (current: 10)'
          )
        end
      end

      context 'when debug is disabled' do
        it 'does not call base logger debug' do
          contextual_logger.debug('Test debug')

          expect(base_logger).not_to have_received(:debug)
        end
      end
    end
  end

  describe 'error class inheritance' do
    it 'RevisionMismatchError inherits from ExponentialRetrier::RetryFailedError' do
      expect(described_class::RevisionMismatchError).to be < Yes::Core::Utils::ExponentialRetrier::RetryFailedError
    end

    it 'TimeoutError inherits from ExponentialRetrier::TimeoutError' do
      expect(described_class::TimeoutError).to be < Yes::Core::Utils::ExponentialRetrier::TimeoutError
    end

    it 'RevisionAlreadyAppliedError inherits from StandardError' do
      expect(described_class::RevisionAlreadyAppliedError).to be < StandardError
    end
  end
end
