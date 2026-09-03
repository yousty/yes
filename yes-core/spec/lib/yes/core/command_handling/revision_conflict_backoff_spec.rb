# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::RevisionConflictBackoff do
  let(:aggregate_id) { SecureRandom.uuid }
  let(:own_stream) { PgEventstore::Stream.new(context: 'Test', stream_name: 'User', stream_id: aggregate_id) }

  before { allow(described_class).to receive(:rand).and_return(0.5) } # neutral jitter

  describe '.delay' do
    subject { described_class.delay(error:, aggregate_id:, read_model_revision:, attempt:) }

    let(:error) do
      PgEventstore::WrongExpectedRevisionError.new(
        revision: 7, expected_revision: 6, stream:, verdict: :unmatched_stream_revision
      )
    end
    let(:stream) { own_stream }
    let(:attempt) { 1 }

    context 'when the read model still reports a revision behind the stream' do
      let(:read_model_revision) { 6 }

      it 'starts at 10 ms' do
        is_expected.to eq(0.01)
      end

      it 'doubles per attempt' do
        delays = (2..7).map { |n| described_class.delay(error:, aggregate_id:, read_model_revision:, attempt: n) }

        expect(delays.map { |d| d.round(4) }).to eq([0.02, 0.04, 0.08, 0.16, 0.32, 0.64])
      end

      it 'stops waiting once the total budget is spent' do
        delays = (8..10).map { |n| described_class.delay(error:, aggregate_id:, read_model_revision:, attempt: n) }

        # 0.01 + … + 0.64 = 1.27 s before attempt 8, so 0.73 s of the 2 s budget remain, then nothing
        expect(delays.map { |d| d.round(2) }).to eq([0.73, 0.0, 0.0])
      end

      it 'applies jitter around the schedule' do
        allow(described_class).to receive(:rand).and_return(1.0)

        is_expected.to be_within(1e-9).of(0.0125)
      end
    end

    context 'when the read model already reflects the stream revision' do
      let(:read_model_revision) { 7 }

      it 'retries immediately' do
        is_expected.to eq(0.0)
      end
    end

    context 'when the read model is ahead of the stream revision' do
      let(:read_model_revision) { 9 }

      it 'retries immediately' do
        is_expected.to eq(0.0)
      end
    end

    context 'when the aggregate has no read model' do
      let(:read_model_revision) { nil }

      it 'retries immediately' do
        is_expected.to eq(0.0)
      end
    end

    context 'when the conflict does not carry a numeric stream revision' do
      let(:error) do
        PgEventstore::WrongExpectedRevisionError.new(
          revision: :no_stream, expected_revision: 6, stream:, verdict: :expected_to_have_stream
        )
      end
      let(:read_model_revision) { 6 }

      it 'retries immediately' do
        is_expected.to eq(0.0)
      end
    end

    context 'when the conflict is on an external aggregate stream' do
      let(:stream) { PgEventstore::Stream.new(context: 'Test', stream_name: 'Location', stream_id: SecureRandom.uuid) }
      let(:read_model_revision) { 9 }

      it 'backs off even though this read model is up to date, because the external one cannot be checked here' do
        is_expected.to eq(0.01)
      end
    end
  end

  describe '.schedule' do
    it 'is the undisturbed exponential schedule shared with the concurrent-update retries' do
      expect((1..8).map { described_class.schedule(_1).round(4) }).to eq([0.01, 0.02, 0.04, 0.08, 0.16, 0.32, 0.64, 1.0])
    end
  end
end
