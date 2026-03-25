# frozen_string_literal: true

RSpec.describe Yes::Core::Subscriptions do
  subject { instance }

  let(:instance) { described_class.new }

  describe '#subscribe_to_all' do
    subject { instance.subscribe_to_all(handler, filter_options) }

    let(:handler) { Dummy::ReadModels::JobApp::Builder.new }
    let(:filter_options) { { event_types: ['SomeEventName'] } }

    it 'creates a subscription' do
      expect { subject }.to change { instance.subscriptions_manager.subscriptions.count }.by(1)
    end

    describe 'created subscription' do
      subject { super(); instance.subscriptions_manager.subscriptions.last }

      it 'has correct setup' do
        expect(subject.options).to eq(filter: filter_options, resolve_link_tos: true)
      end
    end
  end

  describe '#start' do
    subject { instance.start }

    before do
      Yes::Core.configure do |config|
        config.subscriptions_heartbeat_url = "http://localhost:3000/heartbeat"
        config.subscriptions_heartbeat_interval = 1
      end
    end

    after do
      instance.subscriptions_manager.stop
    end

    it 'starts the subscriptions manager' do
      expect { subject }.not_to raise_error
    end
  end
end
