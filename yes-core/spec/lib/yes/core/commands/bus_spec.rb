# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::Bus do
  describe '#call' do
    subject { instance.call(do_something, origin:, notifier_options:, batch_id:) }

    let(:mock_processor) { class_double(Yes::Core::Commands::Processor) }
    let(:instance) { described_class.new(command_processor: mock_processor) }

    let(:origin) { nil }

    let(:batch_id) { SecureRandom.uuid }

    let(:do_something) do
      Dummy::Activity::Commands::DoSomething::Command.new(
        id: SecureRandom.uuid, what: 'Make coffee'
      )
    end

    let(:notifier_options) { { channel: '/cmd_notifications/commands' } }

    around do |example|
      original = Yes::Core.configuration.process_commands_inline
      Yes::Core.configuration.process_commands_inline = false
      example.run
    ensure
      Yes::Core.configuration.process_commands_inline = original
    end

    before do
      allow(mock_processor).to receive(:perform_later)
      allow(mock_processor).to receive(:perform_now).and_return([mock_response])
    end

    let(:mock_response) { Yes::Core::Commands::Response.new(cmd: do_something) }

    it 'calls processor with perform_later' do
      subject

      expect(mock_processor).to have_received(:perform_later).with(
        a_kind_of(String),
        do_something,
        notifier_options,
        batch_id,
        false
      )
    end

    context 'when origin is passed' do
      let(:origin) { 'some origin' }

      it 'calls processor with passed origin' do
        subject

        expect(mock_processor).to have_received(:perform_later).with(
          origin,
          do_something,
          notifier_options,
          batch_id,
          false
        )
      end
    end

    context 'when processing inline' do
      around do |example|
        original = Yes::Core.configuration.process_commands_inline
        Yes::Core.configuration.process_commands_inline = true
        example.run
      ensure
        Yes::Core.configuration.process_commands_inline = original
      end

      it 'returns command responses' do
        aggregate_failures do
          is_expected.to be_an(Array)
          is_expected.to all(be_kind_of(Yes::Core::Commands::Response))
        end
      end

      it 'calls processor with perform_now' do
        subject

        expect(mock_processor).to have_received(:perform_now)
      end
    end

    context 'when running from script' do
      subject do
        eval('described_class.new(command_processor: mock_processor).call(do_something, origin:, notifier_options:, batch_id:)', binding, __FILE__,
             __LINE__ - 1)
      end

      let(:origin) { '(some-script)' }

      it 'calls processor with passed origin' do
        subject

        expect(mock_processor).to have_received(:perform_later).with(
          origin,
          do_something,
          notifier_options,
          batch_id,
          false
        )
      end
    end

    context 'when force inline processing' do
      let(:instance) { described_class.new(command_processor: mock_processor, perform_inline: true) }

      it 'calls processor with perform_now' do
        subject

        expect(mock_processor).to have_received(:perform_now)
      end

      it 'returns command responses' do
        aggregate_failures do
          is_expected.to be_an(Array)
          is_expected.to all(be_kind_of(Yes::Core::Commands::Response))
        end
      end
    end
  end
end
