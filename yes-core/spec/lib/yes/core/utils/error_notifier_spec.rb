# frozen_string_literal: true

RSpec.describe Yes::Core::Utils::ErrorNotifier do
  subject(:notifier) { described_class.new }

  let(:error_reporter) { instance_spy(Proc) }

  before do
    allow(Yes::Core.configuration).to receive(:error_reporter).and_return(error_reporter)
    allow(Yes::Core.configuration).to receive(:logger).and_return(Logger.new(nil))
  end

  describe '#invalid_event_data' do
    let(:event) { instance_double(PgEventstore::Event, to_json: '{"type":"Test"}') }

    it 'reports the error via error_reporter' do
      notifier.invalid_event_data(event)

      expect(error_reporter).to have_received(:call).with(
        an_instance_of(StandardError),
        context: hash_including(:event)
      )
    end
  end

  describe '#payload_extraction_failed' do
    let(:error) { double('Error', extra: { key: 'value' }) }

    it 'reports the error via error_reporter' do
      notifier.payload_extraction_failed(error)

      expect(error_reporter).to have_received(:call).with(
        an_instance_of(StandardError),
        context: { key: 'value' }
      )
    end
  end

  describe '#event_handler_not_defined' do
    let(:event) { instance_double(PgEventstore::Event, to_json: '{"type":"Test"}') }

    context 'when CAPTURE_EVENTSOURCING_ERRORS is true' do
      before { allow(ENV).to receive(:fetch).and_call_original }

      around do |example|
        original = ENV.fetch('CAPTURE_EVENTSOURCING_ERRORS', nil)
        ENV['CAPTURE_EVENTSOURCING_ERRORS'] = 'true'
        example.run
      ensure
        ENV['CAPTURE_EVENTSOURCING_ERRORS'] = original
      end

      it 'reports the error' do
        notifier.event_handler_not_defined('Handler missing', event)

        expect(error_reporter).to have_received(:call)
      end
    end

    context 'when CAPTURE_EVENTSOURCING_ERRORS is not set' do
      it 'does not report the error' do
        notifier.event_handler_not_defined('Handler missing', event)

        expect(error_reporter).not_to have_received(:call)
      end
    end
  end

  describe '#missing_payload_store_client_error' do
    it 'reports the error via error_reporter' do
      notifier.missing_payload_store_client_error

      expect(error_reporter).to have_received(:call).with(
        an_instance_of(StandardError),
        context: {}
      )
    end
  end

  describe '#notify' do
    let(:error) { StandardError.new('test error') }

    it 'calls error_reporter with the error' do
      notifier.notify(error, extra: { detail: 'info' })

      expect(error_reporter).to have_received(:call).with(error, context: { detail: 'info' })
    end

    context 'without extra' do
      it 'calls error_reporter with empty context' do
        notifier.notify(error)

        expect(error_reporter).to have_received(:call).with(error, context: {})
      end
    end
  end

  context 'when error_reporter is not configured' do
    before do
      allow(Yes::Core.configuration).to receive(:error_reporter).and_return(nil)
    end

    it 'does not raise when capturing messages' do
      event = instance_double(PgEventstore::Event, to_json: '{}')
      expect { notifier.invalid_event_data(event) }.not_to raise_error
    end
  end
end
