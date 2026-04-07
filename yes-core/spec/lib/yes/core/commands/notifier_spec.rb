# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::Notifier do
  let(:instance) { described_class.new }

  describe '#notify_batch_started' do
    subject { instance.notify_batch_started(batch_id) }

    let(:batch_id) { SecureRandom.uuid }

    it 'raises NotImplementedError' do
      expect { subject }.to raise_error NotImplementedError
    end
  end

  describe '#notify_batch_finished' do
    subject { instance.notify_batch_finished(batch_id) }

    let(:batch_id) { SecureRandom.uuid }

    it 'raises NotImplementedError' do
      expect { subject }.to raise_error NotImplementedError
    end
  end

  describe '#notify_command_response' do
    subject { instance.notify_command_response(command_response) }

    let(:command_response) { nil }

    it 'raises NotImplementedError' do
      expect { subject }.to raise_error NotImplementedError
    end
  end
end
