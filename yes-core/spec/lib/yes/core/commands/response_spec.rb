# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::Response do
  let(:instance) { described_class.new(cmd:, error:) }

  let(:cmd) { Yes::Core::Command.new(transaction:, origin:, batch_id:, metadata:) }

  let(:transaction) { Yes::Core::TransactionDetails.new }
  let(:origin) { 'origin' }
  let(:batch_id) { SecureRandom.uuid }
  let(:metadata) { { 'meta' => 'data' } }
  let(:error) { nil }

  describe '#success?' do
    subject { instance.success? }

    it { is_expected.to be(true) }

    context 'when error is present' do
      let(:error) { Yes::Core::CommandHandling::GuardEvaluator::TransitionError.new }

      it { is_expected.to be(false) }
    end
  end

  describe '#error_details' do
    subject { instance.error_details }

    it { is_expected.to eq({}) }

    context 'when error is present' do
      let(:error_message) { 'InterstingThing error for you' }
      let(:error) do
        Yes::Core::CommandHandling::GuardEvaluator::TransitionError.new(error_message, extra: { foo: :bar })
      end

      it do
        is_expected.to(
          eq(
            message: error.message,
            type: error.message.underscore.tr(' ', '_'),
            extra: error.extra
          )
        )
      end
    end
  end

  describe '#type' do
    subject { instance.type }

    it { is_expected.to eq('command_success') }

    context 'when error is present' do
      let(:error) { Yes::Core::CommandHandling::GuardEvaluator::TransitionError.new }

      it { is_expected.to eq('command_error') }
    end
  end

  describe '#to_notification' do
    subject { instance.to_notification }

    it 'returns notification hash' do
      expect(subject).to match(
        type: 'command_success',
        batch_id:,
        metadata:,
        payload: cmd.payload,
        command: cmd.class.name,
        id: cmd.command_id,
        transaction: transaction.to_h
      )
    end

    context 'when error is present' do
      let(:error_message) { 'InterstingThing error for you' }
      let(:error) do
        Yes::Core::CommandHandling::GuardEvaluator::TransitionError.new(error_message, extra: { foo: :bar })
      end

      it 'returns notification hash' do
        expect(subject).to match(
          type: 'command_error',
          batch_id:,
          metadata:,
          payload: cmd.payload,
          command: cmd.class.name,
          id: cmd.command_id,
          transaction: transaction.to_h,
          error_details: {
            message: error.message,
            type: error.message.underscore.tr(' ', '_'),
            extra: { foo: :bar }
          }
        )
      end
    end
  end

  describe '#as_json' do
    subject { instance.as_json }

    it { is_expected.to eq(instance.to_notification.as_json) }
  end
end
