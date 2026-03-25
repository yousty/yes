# frozen_string_literal: true

RSpec.describe Yes::Core::ProcessManagers::State do
  subject(:test_state) { test_state_class.new(id) }

  let(:test_state_class) { Dummy::ProcessManagers::TestState }
  let(:id) { SecureRandom.uuid }

  describe '.load' do
    let(:events) do
      {
        'TestEvent::Created' => double('Event', type: 'TestEvent::Created', data: { 'name' => 'Test Name' }),
        'TestEvent::Updated' => double('Event', type: 'TestEvent::Updated', data: { 'status' => 'active' })
      }
    end

    before do
      allow_any_instance_of(test_state_class).to receive(:relevant_events).and_return(events)
    end

    it 'creates a new instance and applies events' do
      state = test_state_class.load(id)

      aggregate_failures do
        expect(state).to be_a(test_state_class)
        expect(state.name).to eq('Test Name')
        expect(state.status).to eq('active')
      end
    end
  end

  describe '#load' do
    let(:events) do
      {
        'TestEvent::Created' => double('Event', type: 'TestEvent::Created', data: { 'name' => 'Test Name' }),
        'TestEvent::Updated' => double('Event', type: 'TestEvent::Updated', data: { 'status' => 'active' })
      }
    end

    before do
      allow(subject).to receive(:relevant_events).and_return(events)
    end

    it 'processes events and applies them to the state' do
      aggregate_failures do
        subject.load
        expect(subject.name).to eq('Test Name')
        expect(subject.status).to eq('active')
      end
    end
  end

  describe '#valid?' do
    context 'when all required attributes are present' do
      before do
        test_state.name = 'Test'
        test_state.status = 'active'
      end

      it 'returns true' do
        expect(test_state.valid?).to be true
      end
    end

    context 'when some required attributes are missing' do
      before do
        test_state.name = 'Test'
      end

      it 'returns false' do
        expect(test_state.valid?).to be false
      end
    end
  end

  describe '#process_events' do
    let(:events) do
      {
        'TestEvent::Created' => double('Event', type: 'TestEvent::Created', data: { 'name' => 'Test Name' }),
        'TestEvent::Updated' => double('Event', type: 'TestEvent::Updated', data: { 'status' => 'active' })
      }
    end

    it 'applies events to the state' do
      aggregate_failures do
        subject.send(:process_events, events)
        expect(subject.name).to eq('Test Name')
        expect(subject.status).to eq('active')
      end
    end

    context 'when an apply method is not implemented' do
      let(:events) do
        {
          'TestEvent::Unknown' => double('Event', type: 'TestEvent::Unknown', data: {})
        }
      end

      it 'raises a NotImplementedError' do
        expect { subject.send(:process_events, events) }.to raise_error(NotImplementedError, /must implement #apply_unknown/)
      end
    end
  end

  describe '#relevant_events' do
    subject(:relevant_events) { test_state.send(:relevant_events, 'test-stream') }

    let(:client) { instance_double(PgEventstore::Client) }
    let(:paginated_read) { instance_double(Enumerator) }
    let(:events) do
      [
        double('Event', type: 'TestEvent::Created', data: { 'name' => 'Test Name' }),
        double('Event', type: 'TestEvent::Updated', data: { 'status' => 'active' })
      ]
    end

    before do
      allow(PgEventstore).to receive(:client).and_return(client)
      allow(client).to receive(:read_paginated).and_return(paginated_read)
      allow(paginated_read).to receive(:each_with_object).and_yield(events, {})
    end

    it 'retrieves relevant events from the stream' do
      expect(relevant_events.keys).to match_array(%w[TestEvent::Created TestEvent::Updated])
    end
  end
end
