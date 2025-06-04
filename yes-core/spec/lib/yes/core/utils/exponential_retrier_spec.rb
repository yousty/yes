# frozen_string_literal: true

RSpec.describe Yes::Core::Utils::ExponentialRetrier do
  subject(:retrier) { described_class.new(**config) }

  let(:config) { {} }
  let(:logger) { instance_double('Logger', info: nil, error: nil, debug: nil, debug?: false) }
  let(:condition_check) do
    lambda {
      @attempt_count += 1
      @attempt_count >= 3
    }
  end
  let(:action_block) { -> { 'success' } }

  before do
    @attempt_count = 0
    allow(retrier).to receive(:sleep)
  end

  describe 'initialization' do
    context 'with default configuration' do
      it 'sets default values' do
        aggregate_failures do
          expect(retrier.send(:max_retries)).to eq(6)
          expect(retrier.send(:base_sleep_time)).to eq(0.1)
          expect(retrier.send(:max_sleep_time)).to eq(5.0)
          expect(retrier.send(:jitter_factor)).to eq(0.1)
          expect(retrier.send(:timeout)).to eq(30)
        end
      end
    end

    context 'with custom configuration' do
      let(:config) do
        {
          max_retries: 3,
          base_sleep_time: 0.5,
          max_sleep_time: 10.0,
          jitter_factor: 0.2,
          timeout: 60,
          logger:
        }
      end

      it 'uses provided configuration' do
        aggregate_failures do
          expect(retrier.send(:max_retries)).to eq(3)
          expect(retrier.send(:base_sleep_time)).to eq(0.5)
          expect(retrier.send(:max_sleep_time)).to eq(10.0)
          expect(retrier.send(:jitter_factor)).to eq(0.2)
          expect(retrier.send(:timeout)).to eq(60)
          expect(retrier.send(:logger)).to eq(logger)
        end
      end
    end
  end

  describe '#call' do
    context 'when condition is met on first attempt' do
      let(:condition_check) { -> { true } }

      it 'executes action immediately without retries' do
        result = retrier.call(condition_check:, action: action_block)

        aggregate_failures do
          expect(result).to eq('success')
          expect(retrier).not_to have_received(:sleep)
        end
      end

      it 'does not log when successful on first attempt' do
        retrier = described_class.new(logger:)
        retrier.call(condition_check:, action: action_block)

        expect(logger).not_to have_received(:info)
      end

      it 'works with block syntax' do
        result = retrier.call(condition_check:) { 'block success' }

        expect(result).to eq('block success')
      end
    end

    context 'when condition is met after retries' do
      it 'retries until condition is met' do
        result = retrier.call(condition_check:, action: action_block)

        aggregate_failures do
          expect(result).to eq('success')
          expect(@attempt_count).to eq(3)
          expect(retrier).to have_received(:sleep).twice
        end
      end

      it 'logs success when condition met after retries' do
        retrier = described_class.new(logger:)
        retrier.call(condition_check:, action: action_block)

        expect(logger).to have_received(:info).with(/succeeded after 2 attempts/)
      end

      it 'uses exponential backoff for sleep times' do
        retrier.call(condition_check:, action: action_block)

        aggregate_failures do
          # First sleep should be around 0.1s ± 10%
          expect(retrier).to have_received(:sleep).with(a_value_between(0.09, 0.11)).ordered
          # Second sleep should be around 0.2s ± 10%
          expect(retrier).to have_received(:sleep).with(a_value_between(0.18, 0.22)).ordered
        end
      end
    end

    context 'when condition is never met' do
      let(:condition_check) { -> { false } }

      it 'raises RetryFailedError after maximum retries' do
        expect do
          retrier.call(condition_check:, action: action_block)
        end.to raise_error(
          described_class::RetryFailedError,
          'Retry failed after 6 attempts'
        )
      end

      it 'uses custom failure message when provided' do
        expect do
          retrier.call(
            condition_check:,
            action: action_block,
            failure_message: 'Custom failure message'
          )
        end.to raise_error(
          described_class::RetryFailedError,
          'Custom failure message'
        )
      end

      it 'logs error when failing after maximum retries' do
        retrier = described_class.new(logger:)

        expect do
          retrier.call(condition_check:, action: action_block)
        end.to raise_error(described_class::RetryFailedError)

        expect(logger).to have_received(:error).with(/failed after 6 attempts/)
      end

      it 'performs exactly max_retries attempts' do
        expect do
          retrier.call(condition_check:, action: action_block)
        end.to raise_error(described_class::RetryFailedError)

        expect(retrier).to have_received(:sleep).exactly(5).times
      end
    end

    context 'with timeout' do
      before do
        start_time = Time.current
        allow(Time).to receive(:current).and_return(
          start_time,
          start_time + 31.seconds
        )
      end

      it 'raises TimeoutError when timeout is exceeded' do
        expect do
          retrier.call(condition_check:, action: action_block)
        end.to raise_error(
          described_class::TimeoutError,
          'Timeout after 31.0s'
        )
      end

      it 'uses custom timeout message when provided' do
        expect do
          retrier.call(
            condition_check:,
            action: action_block,
            timeout_message: 'Custom timeout message'
          )
        end.to raise_error(
          described_class::TimeoutError,
          'Custom timeout message'
        )
      end
    end

    context 'with debug logging enabled' do
      before do
        allow(logger).to receive(:debug?).and_return(true)
      end

      it 'logs retry attempts when debug is enabled' do
        retrier = described_class.new(logger:)
        retrier.call(condition_check:, action: action_block)

        aggregate_failures do
          expect(logger).to have_received(:debug).with(%r{retry 1/6}).ordered
          expect(logger).to have_received(:debug).with(%r{retry 2/6}).ordered
        end
      end
    end

    context 'when action raises an error' do
      let(:condition_check) { -> { true } }
      let(:action_block) { -> { raise StandardError, 'Action failed' } }

      it 'propagates the error from action' do
        expect do
          retrier.call(condition_check:, action: action_block)
        end.to raise_error(StandardError, 'Action failed')
      end
    end

    context 'when neither action nor block is provided' do
      it 'raises ArgumentError' do
        expect do
          retrier.call(condition_check:)
        end.to raise_error(ArgumentError, 'Either action parameter or block must be provided')
      end
    end
  end

  describe '#calculate_sleep_time' do
    let(:config) { { jitter_factor: 0.1 } }

    it 'calculates exponential backoff correctly' do
      aggregate_failures do
        # Attempt 1: 0.1 * 2^0 = 0.1 ± jitter
        expect(retrier.send(:calculate_sleep_time, 1)).to be_between(0.09, 0.11)
        # Attempt 2: 0.1 * 2^1 = 0.2 ± jitter
        expect(retrier.send(:calculate_sleep_time, 2)).to be_between(0.18, 0.22)
        # Attempt 3: 0.1 * 2^2 = 0.4 ± jitter
        expect(retrier.send(:calculate_sleep_time, 3)).to be_between(0.36, 0.44)
      end
    end

    it 'adds jitter to prevent thundering herd' do
      # Run multiple times to verify randomness
      sleep_times = Array.new(10) { retrier.send(:calculate_sleep_time, 1) }

      aggregate_failures do
        # All should be within ±10% of base time (0.1s)
        expect(sleep_times).to all(be_between(0.09, 0.11))
        # But they should not all be the same (jitter is working)
        expect(sleep_times.uniq.size).to be > 1
      end
    end

    it 'caps sleep time at maximum' do
      # High attempt number would normally result in very long sleep
      sleep_time = retrier.send(:calculate_sleep_time, 10)

      aggregate_failures do
        expect(sleep_time).to be <= 5.0
        # Should still be close to max with jitter
        expect(sleep_time).to be >= 4.5
      end
    end

    context 'with custom configuration' do
      let(:config) do
        {
          base_sleep_time: 0.5,
          max_sleep_time: 2.0,
          jitter_factor: 0.2
        }
      end

      it 'uses custom base sleep time' do
        # Attempt 1: 0.5 * 2^0 = 0.5 ± 20%
        expect(retrier.send(:calculate_sleep_time, 1)).to be_between(0.4, 0.6)
      end

      it 'respects custom maximum sleep time' do
        sleep_time = retrier.send(:calculate_sleep_time, 10)
        expect(sleep_time).to be <= 2.0
      end
    end
  end

  describe 'error classes' do
    it 'defines RetryFailedError' do
      expect(described_class::RetryFailedError).to be < StandardError
    end

    it 'defines TimeoutError' do
      expect(described_class::TimeoutError).to be < StandardError
    end
  end

  describe 'constants' do
    it 'defines default configuration constants' do
      aggregate_failures do
        expect(described_class::DEFAULT_MAX_RETRIES).to eq(6)
        expect(described_class::DEFAULT_BASE_SLEEP_TIME).to eq(0.1)
        expect(described_class::DEFAULT_MAX_SLEEP_TIME).to eq(5.0)
        expect(described_class::DEFAULT_JITTER_FACTOR).to eq(0.1)
        expect(described_class::DEFAULT_TIMEOUT).to eq(30)
      end
    end
  end
end
