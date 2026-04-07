# frozen_string_literal: true

require 'message_bus'
require 'yes/command/api/commands/notifiers/message_bus'

RSpec.describe Yes::Core::Commands::Processor do
  let(:processor) { described_class.new }
  let(:origin) { 'some origin' }
  let(:notifier_options) { { channel: '/cmd_notifications/commands' } }
  let(:batch_id) { nil }

  let(:single_command) do
    Dummy::Activity::Commands::DoSomething::Command.new(
      id: SecureRandom.uuid, what: 'Make coffee'
    )
  end

  let(:do_something) { single_command }

  let(:single_response) do
    Yes::Core::Commands::Response.new(cmd: single_command)
  end

  let(:aggregate_instance) { instance_double('Aggregate') }
  let(:aggregate_class) { double('AggregateClass') }

  before do
    # Stub guard evaluator check to pass for registered commands
    allow(Yes::Core.configuration).to receive(:guard_evaluator_class).and_return(double('GuardEvaluator'))

    # Stub aggregate class resolution
    allow(aggregate_class).to receive(:new).and_return(aggregate_instance)
    allow(aggregate_instance).to receive(:do_something).and_return(single_response)
    allow(aggregate_instance).to receive(:do_something_else).and_return(single_response)

    allow_any_instance_of(described_class).to receive(:aggregate_class).and_return(aggregate_class)
  end

  describe '.queue_name' do
    it 'uses the commands queue' do
      expect(described_class.queue_name).to eq('commands')
    end
  end

  describe '.perform_now' do
    subject do
      processor.perform(origin, do_something, notifier_options, batch_id)
    end

    let(:notifier_class1) do
      Class.new(Yes::Core::Commands::Notifier) do
        def notify_batch_started(*, **); end
        def notify_batch_finished(*, **); end
        def notify_command_response(_); end
        def initialize(_opts = {}); end # rubocop:disable Lint/MissingSuper
      end
    end
    let(:notifier_class2) do
      Class.new(Yes::Core::Commands::Notifier) do
        def notify_batch_started(*, **); end
        def notify_batch_finished(*, **); end
        def notify_command_response(_); end
        def initialize(_opts = {}); end # rubocop:disable Lint/MissingSuper
      end
    end
    let(:notifier1) { instance_spy(notifier_class1) }
    let(:notifier2) { instance_spy(notifier_class2) }

    around do |example|
      original = Yes::Core.configuration.command_notifier_classes
      Yes::Core.configuration.command_notifier_classes = [notifier_class1, notifier_class2]
      example.run
    ensure
      Yes::Core.configuration.command_notifier_classes = original
    end

    before do
      ActiveJob::Base.logger = Logger.new(nil)

      allow(notifier_class1).to receive(:new).and_return(notifier1)
      allow(notifier_class2).to receive(:new).and_return(notifier2)
    end

    shared_examples 'sends notifications' do
      it 'notifies batch started' do
        subject
        aggregate_failures do
          expect(notifier1).to have_received(:notify_batch_started)
          expect(notifier2).to have_received(:notify_batch_started)
        end
      end

      it 'notifies batch finished' do
        subject
        aggregate_failures do
          expect(notifier1).to have_received(:notify_batch_finished)
          expect(notifier2).to have_received(:notify_batch_finished)
        end
      end

      it 'notifies command responses' do
        subject
        aggregate_failures do
          expect(notifier1).to(
            have_received(:notify_command_response).exactly([*do_something].size).times
          )
          expect(notifier2).to(
            have_received(:notify_command_response).exactly([*do_something].size).times
          )
        end
      end
    end

    context 'when command is registered' do
      it_behaves_like 'sends notifications'

      it 'returns array of command responses' do
        expect(subject).to all(be_a(Yes::Core::Commands::Response))
      end

      it 'calls the aggregate with correct command name' do
        subject

        expect(aggregate_instance).to have_received(:do_something)
      end

      it 'instantiates aggregate with correct id' do
        subject

        expect(aggregate_class).to have_received(:new).with(do_something.id, draft: nil)
      end
    end

    context 'when a command is unregistered' do
      before do
        allow(Yes::Core.configuration).to receive(:guard_evaluator_class).and_return(nil)
      end

      it 'raises an error' do
        expect { subject }.to raise_error(
          Yes::Core::Commands::Processor::UnregisteredCommand
        )
      end
    end

    context 'with multiple commands' do
      let(:do_something) do
        [
          Dummy::Activity::Commands::DoSomething::Command.new(
            id: SecureRandom.uuid, what: 'Make coffee'
          ),
          Dummy::Activity::Commands::DoSomethingElse::Command.new(
            id: SecureRandom.uuid, what: 'Make tea'
          )
        ]
      end

      before do
        allow(aggregate_instance).to receive(:do_something).and_return(
          Yes::Core::Commands::Response.new(cmd: do_something[0])
        )
        allow(aggregate_instance).to receive(:do_something_else).and_return(
          Yes::Core::Commands::Response.new(cmd: do_something[1])
        )
      end

      context 'when all commands are registered' do
        it_behaves_like 'sends notifications'

        it 'returns array of command responses' do
          expect(subject).to all(be_a(Yes::Core::Commands::Response))
        end

        it 'processes both commands' do
          subject

          aggregate_failures do
            expect(aggregate_instance).to have_received(:do_something)
            expect(aggregate_instance).to have_received(:do_something_else)
          end
        end
      end

      context 'when any command is unregistered' do
        before do
          allow(Yes::Core.configuration).to receive(:guard_evaluator_class).and_return(nil)
        end

        it 'raises an error' do
          expect { subject }.to raise_error(
            Yes::Core::Commands::Processor::UnregisteredCommand
          )
        end
      end
    end

    context 'with a CommandGroup' do
      let(:company_id) { SecureRandom.uuid }
      let(:user_id) { SecureRandom.uuid }
      let(:do_something) do
        Dummy::Company::Commands::DoSomethingCompounded::Command.new(
          company: {
            company_id:,
            name: 'New Company Name',
            description: 'New Company Description'
          },
          user: {
            user_id:,
            first_name: 'John',
            last_name: 'Doe'
          }
        )
      end

      let(:group_response) do
        Yes::Core::Commands::Response.new(cmd: do_something.commands.first)
      end

      before do
        # Group commands don't have aggregate_id, so stub run_command directly
        allow_any_instance_of(described_class).to receive(:run_command).and_return(group_response)
      end

      it_behaves_like 'sends notifications'

      it 'returns array of command responses' do
        expect(subject).to all(be_a(Yes::Core::Commands::Response))
      end
    end

    context 'with origin handling' do
      it 'passes origin to the command' do
        subject

        expect(aggregate_instance).to have_received(:do_something).with(
          hash_including(origin:),
          guards: true
        )
      end

      context 'when origin is nil' do
        let(:origin) { nil }

        it 'passes nil origin' do
          subject

          expect(aggregate_instance).to have_received(:do_something).with(
            hash_including(origin: nil),
            guards: true
          )
        end
      end
    end

    context 'with batch_id' do
      let(:batch_id) { SecureRandom.uuid }

      it 'passes batch_id to the command' do
        subject

        expect(aggregate_instance).to have_received(:do_something).with(
          hash_including(batch_id:),
          guards: true
        )
      end
    end

    context 'with message bus notifier' do
      let(:channel_id) { SecureRandom.uuid }
      let(:notifier_options) { { channel: "/cmd_notifications/commands/#{channel_id}" } }
      let(:published_messages) { [] }

      around do |example|
        original = Yes::Core.configuration.command_notifier_classes
        Yes::Core.configuration.command_notifier_classes = [Yes::Command::Api::Commands::Notifiers::MessageBus]
        example.run
      ensure
        Yes::Core.configuration.command_notifier_classes = original
      end

      before do
        allow(MessageBus).to receive(:publish) do |_channel, data, **_opts|
          published_messages << data
        end
      end

      it 'publishes batch_started and batch_finished to the message bus' do
        subject

        aggregate_failures do
          expect(published_messages.count).to eq(3)
          expect(published_messages[0][:type]).to eq('batch_started')
          expect(published_messages[0][:commands]).to(
            eq(
              [{
                command: 'Dummy::Activity::Commands::DoSomething::Command',
                command_id: do_something.command_id
              }]
            )
          )
          expect(published_messages[1][:type]).to eq('command_success')
          expect(published_messages[1][:id]).to eq(do_something.command_id)
          expect(published_messages[2][:type]).to eq('batch_finished')
          expect(published_messages[1][:command]).to eq('Dummy::Activity::Commands::DoSomething::Command')

          batch_messages = published_messages.values_at(0, 2)
          expect(batch_messages.pluck(:batch_id).uniq.length).to eq(1)
        end
      end

      context 'when batch_id is passed' do
        let(:batch_id) { SecureRandom.uuid }

        it 'publishes correct batch_id to batch messages' do
          subject
          batch_messages = published_messages.values_at(0, 2)
          expect(batch_messages.pluck(:batch_id)).to all(eq(batch_id))
        end
      end

      context 'when command fails' do
        let(:error_response) do
          Yes::Core::Commands::Response.new(
            cmd: do_something,
            error: Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition.new('Not allowed')
          )
        end

        before do
          allow(aggregate_instance).to receive(:do_something).and_return(error_response)
        end

        it 'publishes error notification to the message bus' do
          subject

          aggregate_failures do
            expect(published_messages.count).to eq(3)
            expect(published_messages[0][:type]).to eq('batch_started')
            expect(published_messages[1][:type]).to eq('command_error')
            expect(published_messages[1][:id]).to eq(do_something.command_id)
            expect(published_messages[2][:type]).to eq('batch_finished')
            expect(published_messages[2][:failed_commands]).to eq(
              [
                {
                  command: 'Dummy::Activity::Commands::DoSomething::Command',
                  command_id: do_something.command_id,
                  error: 'Not allowed'
                }
              ]
            )
          end
        end
      end
    end
  end
end
