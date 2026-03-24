# frozen_string_literal: true

RSpec.describe Yes::Core::Jobs::ReadModelRecoveryJob do
  let(:job) { described_class.new }

  describe '#perform' do
    let(:recovery_results) do
      [
        Yes::Core::CommandHandling::ReadModelRecoveryService::RecoveryResult.new(
          success: true,
          read_model: double('ReadModel1')
        ),
        Yes::Core::CommandHandling::ReadModelRecoveryService::RecoveryResult.new(
          success: false,
          read_model: double('ReadModel2'),
          error_message: 'Recovery failed'
        )
      ]
    end

    before do
      allow(Yes::Core::CommandHandling::ReadModelRecoveryService).
        to receive(:recover_all_stuck_read_models).and_return(recovery_results)
      allow(job).to receive(:track_metrics)
      allow(job).to receive(:check_for_long_stuck_models)
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:warn)

      # Reset circuit breaker state
      described_class.consecutive_failures = 0
      described_class.circuit_opened_at = nil
    end

    context 'when circuit breaker is closed' do
      it 'performs recovery scan' do
        expect(Yes::Core::CommandHandling::ReadModelRecoveryService).
          to receive(:recover_all_stuck_read_models).
          with(stuck_timeout: 1.minute, batch_size: 100)

        job.perform
      end

      it 'tracks metrics for successful and failed recoveries' do
        expect(job).to receive(:track_metrics).with(successful: 1, failed: 1)
        job.perform
      end

      it 'checks for long stuck models' do
        expect(job).to receive(:check_for_long_stuck_models)
        job.perform
      end

      it 'resets consecutive failures on success' do
        job.perform
        expect(described_class.consecutive_failures).to eq 0
      end

      it 'logs completion message' do
        expect(Rails.logger).to receive(:info).with(/Read model recovery scan completed: 2 models processed/)
        job.perform
      end
    end

    context 'when circuit breaker is open' do
      before do
        described_class.circuit_opened_at = 1.minute.ago
      end

      it 'skips execution and logs warning' do
        expect(Rails.logger).to receive(:warn).with(/circuit breaker is open/)
        expect(Yes::Core::CommandHandling::ReadModelRecoveryService).
          not_to receive(:recover_all_stuck_read_models)

        job.perform
      end

      context 'when circuit breaker timeout has expired' do
        before do
          described_class.circuit_opened_at = 10.minutes.ago
        end

        it 'resets circuit breaker and performs recovery' do
          expect(Rails.logger).to receive(:info).with(/circuit breaker timeout expired/)
          expect(Yes::Core::CommandHandling::ReadModelRecoveryService).
            to receive(:recover_all_stuck_read_models)

          job.perform

          expect(described_class.circuit_opened_at).to be_nil
          expect(described_class.consecutive_failures).to eq 0
        end
      end
    end

    context 'when job fails' do
      before do
        allow(Yes::Core::CommandHandling::ReadModelRecoveryService).
          to receive(:recover_all_stuck_read_models).and_raise(StandardError, 'Test error')
        allow(Rails.logger).to receive(:error)
      end

      it 'increments consecutive failures' do
        expect { job.perform }.to raise_error(StandardError)
        expect(described_class.consecutive_failures).to eq 1
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/ReadModelRecoveryJob failed/)
        expect { job.perform }.to raise_error(StandardError)
      end

      context 'when reaching max consecutive failures' do
        before do
          described_class.consecutive_failures = 4 # One more will trigger circuit breaker
          allow(job).to receive(:alert_on_circuit_breaker_open)
        end

        it 'opens circuit breaker' do
          expect { job.perform }.to raise_error(StandardError)

          expect(described_class.circuit_opened_at).not_to be_nil
          expect(described_class.consecutive_failures).to eq 5
        end

        it 'sends critical alert' do
          expect(job).to receive(:alert_on_circuit_breaker_open)
          expect { job.perform }.to raise_error(StandardError)
        end
      end
    end

    context 'when there are many failures' do
      let(:recovery_results) do
        Array.new(3) do
          Yes::Core::CommandHandling::ReadModelRecoveryService::RecoveryResult.new(
            success: false,
            read_model: double('ReadModel'),
            error_message: 'Failed'
          )
        end
      end

      before do
        allow(job).to receive(:alert_on_high_failure_rate)
      end

      it 'alerts on high failure rate' do
        expect(job).to receive(:alert_on_high_failure_rate).with(3, 3)
        job.perform
      end
    end
  end

  describe '#check_for_long_stuck_models' do
    let(:long_stuck_model) do
      double('ReadModel', id: '123', class: double(name: 'TestReadModel'))
    end

    before do
      allow(job).to receive(:find_long_stuck_models).and_return([long_stuck_model])
      allow(job).to receive(:alert_on_long_stuck_models)
    end

    it 'finds models stuck for more than 5 minutes' do
      expect(job).to receive(:find_long_stuck_models).with(5.minutes)
      job.send(:check_for_long_stuck_models)
    end

    it 'alerts when long stuck models are found' do
      expect(job).to receive(:alert_on_long_stuck_models).with([long_stuck_model])
      job.send(:check_for_long_stuck_models)
    end
  end

  describe '#track_metrics' do
    it 'logs metrics to Rails logger' do
      expect(Rails.logger).to receive(:info).with('Recovery metrics - Successful: 5, Failed: 2')
      job.send(:track_metrics, successful: 5, failed: 2)
    end
  end
end
