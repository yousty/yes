# frozen_string_literal: true

require_relative '../../../../../../rails_helper'
require 'yes/command/api/commands/notifiers/action_cable'

RSpec.describe Yes::Command::Api::Commands::Notifiers::ActionCable do
  let(:instance) { described_class.new({ channel: }) }
  let(:channel) { 'my-awesome-channel' }
  before do
    require 'action_cable'
    allow(ActionCable.server).to receive(:broadcast)
  end

  describe '#notify_batch_started', timecop: true do
    subject { instance.notify_batch_started(batch_id, transaction, [command]) }

    let(:batch_id) { SecureRandom.uuid }
    let(:transaction) { Yes::Core::TransactionDetails.new(name: 'trx_details') }
    let(:command) do
      Dummy::Activity::Commands::DoSomething::Command.new(
        what: 'something', id: SecureRandom.uuid
      )
    end

    it 'broadcasts to ActionCable' do
      subject

      expect(ActionCable.server).to have_received(:broadcast).with(
        channel,
        hash_including(
          batch_id:,
          type: 'batch_started',
          transaction: transaction.to_h,
          commands: [{ command: command.class.to_s, command_id: command.command_id }]
        )
      )
    end
  end

  describe '#notify_batch_finished', timecop: true do
    subject { instance.notify_batch_finished(batch_id, transaction, [response]) }

    let(:batch_id) { SecureRandom.uuid }
    let(:transaction) { Yes::Core::TransactionDetails.new(name: 'trx_details') }
    let(:command) do
      Dummy::Activity::Commands::DoSomething::Command.new(
        what: 'something', id: SecureRandom.uuid
      )
    end
    let(:response) { Yes::Core::Commands::Response.new(cmd: command) }

    it 'broadcasts to ActionCable' do
      subject

      expect(ActionCable.server).to have_received(:broadcast).with(
        channel,
        hash_including(
          batch_id:,
          type: 'batch_finished',
          transaction: transaction.to_h
        )
      )
    end

    context 'when response contains errors' do
      let(:error) { Yes::Core::CommandHandling::GuardEvaluator::TransitionError.new('test error') }
      let(:response) { Yes::Core::Commands::Response.new(cmd: command, error:) }

      it 'includes failed commands' do
        subject

        expect(ActionCable.server).to have_received(:broadcast).with(
          channel,
          hash_including(
            failed_commands: [{ command: command.class.to_s, command_id: command.command_id, error: error.to_s }]
          )
        )
      end
    end
  end

  describe '#notify_command_response', timecop: true do
    subject { instance.notify_command_response(response) }

    let(:command) do
      Dummy::Activity::Commands::DoSomething::Command.new(
        what: 'something', id: SecureRandom.uuid
      )
    end
    let(:response) { Yes::Core::Commands::Response.new(cmd: command) }

    it 'broadcasts to ActionCable' do
      subject

      expect(ActionCable.server).to have_received(:broadcast).with(
        channel,
        hash_including(
          type: 'command_success',
          command: command.class.to_s
        )
      )
    end
  end
end
