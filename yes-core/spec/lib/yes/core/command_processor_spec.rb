# frozen_string_literal: true

RSpec.describe Yes::Core::CommandProcessor do
  subject(:processor) { described_class.new }

  let(:command) do
    Test::User::Commands::ChangeName::Command.new(
      user_id:,
      name:
    )
  end
  let(:user_id) { SecureRandom.uuid }
  let(:name) { 'New Name' }
  let(:origin) { 'test_origin' }
  let(:notifier_options) { { environment: 'test' } }

  let(:command_notifier) { instance_double('CommandNotifier') }

  before do
    allow(Yousty::Eventsourcing.config).to receive(:command_notifier_class).
      and_return(double(new: command_notifier))
  end

  describe '#perform' do
    subject { processor.perform(origin, commands, notifier_options) }

    let(:commands) { command }

    context 'with a single command' do
      it 'processes the command successfully' do
        expect(command_notifier).to receive(:with_batch_notification).
          with(processor.job_id, [kind_of(Test::User::Commands::ChangeName::Command)]).
          and_yield

        expect(command_notifier).to receive(:notify_command_response)

        subject
      end
    end

    context 'with multiple commands' do
      let(:commands) { [command, command.clone] }

      it 'processes all commands' do
        expect(command_notifier).to receive(:with_batch_notification).
          with(processor.job_id, kind_of(Array)).
          and_yield

        expect(command_notifier).to receive(:notify_command_response).twice

        subject
      end
    end

    context 'with unregistered command' do
      before do
        allow(Yes::Core.configuration).to receive(:handler_class).
          with('Test', 'User', 'change_name').
          and_return(nil)
      end

      it 'raises UnregisteredCommand error' do
        expect { subject }.to raise_error(Yes::Core::CommandProcessor::UnregisteredCommand)
      end
    end

    context 'without command notifier configured' do
      before do
        allow(Yousty::Eventsourcing.config).to receive(:command_notifier_class).and_return(nil)
      end

      it 'processes commands without notifications' do
        expect { subject }.not_to raise_error
      end
    end
  end
end
