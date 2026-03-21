# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Yes::Command::Api::Commands::Notifiers::MessageBus do
  let(:instance) { described_class.new(channel:) }

  let(:channel) { "/cmd_notifications/#{channel_id}" }
  let(:channel_id) { SecureRandom.uuid }
  let(:transaction) { Yes::Core::TransactionDetails.new(transaction_data) }

  let(:transaction_data) do
    {
      caller_id: user_id,
      caller_type: 'User',
      name: 'test_transaction',
      correlation_id: SecureRandom.uuid,
      causation_id: SecureRandom.uuid
    }
  end

  let(:user_id) { SecureRandom.uuid }
  let(:published_at) { Time.now.to_i }

  let(:cmd) do
    Dummy::Commands::Activity::DoSomething.new(
      transaction:,
      what: 'something',
      id: SecureRandom.uuid
    )
  end

  before do
    allow(MessageBus).to receive(:publish)
  end

  shared_examples 'publish message' do
    before do
      allow(MessageBus).to receive(:publish).and_call_original
    end

    it 'publishes the correct message to the message bus' do
      subject
      expect(MessageBus).to have_received(:publish).with(channel, hash_including(message), user_ids: [user_id])
    end
  end

  describe '#notify_command_response', timecop: true do
    subject { instance.notify_command_response(cmd_response) }

    let(:message) do
      cmd_response.to_notification.merge(
        published_at:
      )
    end
    let(:cmd_response) { Yes::Core::Commands::Response.new(cmd:) }

    it_behaves_like 'publish message'
  end

  describe '#notify_batch_started', timecop: true do
    subject { instance.notify_batch_started(batch_id, transaction, commands) }

    let(:batch_id) { SecureRandom.uuid }
    let(:commands) { [cmd] }
    let(:message) do
      {
        batch_id:,
        published_at:,
        type: 'batch_started',
        transaction: transaction.to_h,
        commands: [{
          command: 'Dummy::Commands::Activity::DoSomething',
          command_id: cmd.command_id
        }]
      }
    end

    it_behaves_like 'publish message'
  end

  describe '#notify_batch_finished', timecop: true do
    subject { instance.notify_batch_finished(batch_id, transaction, responses) }

    let(:batch_id) { SecureRandom.uuid }
    let(:responses) { [cmd_response] }
    let(:message) do
      {
        batch_id:,
        published_at:,
        type: 'batch_finished',
        transaction: transaction.to_h,
        failed_commands: [{
          command: 'Dummy::Commands::Activity::DoSomething',
          error: 'some error',
          command_id: cmd.command_id
        }]
      }
    end

    let(:cmd_response) do
      Yes::Core::Commands::Response.new(
        cmd:,
        error: Yes::Core::CommandHandling::GuardEvaluator::TransitionError.new('some error')
      )
    end

    it_behaves_like 'publish message'
  end
end
