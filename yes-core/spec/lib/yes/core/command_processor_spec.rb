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
    allow(Yousty::Eventsourcing.config).to receive(:command_notifier_classes).
      and_return([double(new: command_notifier)])
  end

  describe '#perform' do
    subject { processor.perform(origin, commands, notifier_options) }

    let(:commands) { command }

    context 'with a single command' do
      it 'processes the command successfully' do
        expect(Yes::Core::CommandNotifier).to receive(:with_batch_notification).
          with([command_notifier], processor.job_id, [kind_of(Test::User::Commands::ChangeName::Command)]).
          and_yield

        expect(command_notifier).to receive(:notify_command_response)

        subject
      end
    end

    context 'with multiple commands' do
      let(:commands) { [command, command.clone] }

      it 'processes all commands' do
        expect(Yes::Core::CommandNotifier).to receive(:with_batch_notification).
          with([command_notifier], processor.job_id, kind_of(Array)).
          and_yield

        expect(command_notifier).to receive(:notify_command_response).twice

        subject
      end
    end

    context 'with unregistered command' do
      before do
        allow(Yes::Core.configuration).to receive(:guard_evaluator_class).
          with('Test', 'User', 'change_name').
          and_return(nil)
      end

      it 'raises UnregisteredCommand error' do
        expect { subject }.to raise_error(Yes::Core::CommandProcessor::UnregisteredCommand)
      end
    end

    context 'without command notifier configured' do
      before do
        allow(Yousty::Eventsourcing.config).to receive(:command_notifier_classes).and_return(nil)
      end

      it 'processes commands without notifications' do
        expect { subject }.not_to raise_error
      end
    end

    context 'with draft metadata in command' do
      let(:draft_command) do
        Test::User::Commands::ChangeName::Command.new(
          user_id:,
          name:,
          metadata: { draft: true }
        )
      end
      let(:commands) { draft_command }
      let(:aggregate_instance) { instance_double(Test::User::Aggregate, public_send: nil) }

      before do
        allow(Test::User::Aggregate).to receive(:new).and_return(aggregate_instance)
        allow(Yousty::Eventsourcing.config).to receive(:command_notifier_classes).and_return(nil)
      end

      it 'instantiates aggregate with draft: true' do
        subject
        expect(Test::User::Aggregate).to have_received(:new).with(user_id, draft: true)
      end

      it 'preserves draft metadata through command processing and disables guards' do
        subject
        expect(aggregate_instance).to have_received(:public_send).with(
          'change_name',
          hash_including(metadata: { draft: true }),
          guards: false
        )
      end
    end

    context 'with edit_template_command metadata in command' do
      let(:edit_template_command) do
        Test::User::Commands::ChangeName::Command.new(
          user_id:,
          name:,
          metadata: { edit_template_command: true }
        )
      end
      let(:commands) { edit_template_command }
      let(:aggregate_instance) { instance_double(Test::User::Aggregate, public_send: nil) }

      before do
        allow(Test::User::Aggregate).to receive(:new).and_return(aggregate_instance)
        allow(Yousty::Eventsourcing.config).to receive(:command_notifier_classes).and_return(nil)
      end

      it 'instantiates aggregate with draft: true' do
        subject
        expect(Test::User::Aggregate).to have_received(:new).with(user_id, draft: true)
      end

      it 'preserves edit_template_command metadata through command processing and disables guards' do
        subject
        expect(aggregate_instance).to have_received(:public_send).with(
          'change_name',
          hash_including(metadata: { edit_template_command: true }),
          guards: false
        )
      end
    end

    context 'without draft metadata in command' do
      let(:aggregate_instance) { instance_double(Test::User::Aggregate, public_send: nil) }

      before do
        allow(Test::User::Aggregate).to receive(:new).and_return(aggregate_instance)
        allow(Yousty::Eventsourcing.config).to receive(:command_notifier_classes).and_return(nil)
      end

      it 'instantiates aggregate without draft parameter' do
        subject
        expect(Test::User::Aggregate).to have_received(:new).with(user_id, draft: nil)
      end

      it 'enables guards when not in draft mode' do
        subject
        expect(aggregate_instance).to have_received(:public_send).with(
          'change_name',
          hash_including(user_id:, name:),
          guards: true
        )
      end
    end

    context 'with inline parameter set to true' do
      subject { processor.perform(origin, commands, notifier_options, nil, true) }

      it 'does not call any notifiers' do
        expect(Yes::Core::CommandNotifier).not_to receive(:with_batch_notification)
        expect(command_notifier).not_to receive(:notify_command_response)

        subject
      end

      it 'adds origin and batch_id to commands' do
        allow(Test::User::Aggregate).to receive(:new) do |user_id, **_opts|
          aggregate_instance = instance_double(Test::User::Aggregate, public_send: nil)
          allow(aggregate_instance).to receive(:public_send) do |_method_name, cmd_hash, **_kwargs|
            # Verify the command hash passed to aggregate has origin and batch_id
            aggregate_failures do
              expect(cmd_hash[:origin]).to eq(origin)
              expect(cmd_hash[:batch_id]).to eq(processor.job_id)
            end
          end
          aggregate_instance
        end

        subject
      end

      it 'returns command responses' do
        result = subject

        aggregate_failures do
          expect(result).to be_an(Array)
          expect(result.first).to be_a(Yes::Core::CommandResponse)
        end
      end
    end

    context 'with inline parameter set to false or not provided' do
      subject { processor.perform(origin, commands, notifier_options, nil, false) }

      it 'uses batch notification when notifiers are configured' do
        expect(Yes::Core::CommandNotifier).to receive(:with_batch_notification).
          with([command_notifier], processor.job_id, [kind_of(Test::User::Commands::ChangeName::Command)]).
          and_yield

        expect(command_notifier).to receive(:notify_command_response)

        subject
      end
    end
  end
end
