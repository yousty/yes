# frozen_string_literal: true

RSpec.describe Yes::Core::EventClassResolver do
  describe '#call' do
    subject { described_class.new.call(event_type) }

    context 'when event class exists' do
      let(:event_type) { 'Yes::Core::Event' }

      it 'returns a proxy that creates events with skip_validation' do
        expect(subject).not_to eq(Yes::Core::Event)
        event = subject.new(type: 'Yes::Core::Event', data: {})
        expect(event).to be_a(Yes::Core::Event)
      end
    end

    context 'when event class does not exist' do
      let(:event_type) { 'NonExistent::EventClass' }

      it 'returns the base Event class' do
        expect(subject).to eq(Yes::Core::Event)
      end
    end

    context 'when event type is nil' do
      let(:event_type) { nil }

      it 'returns the base Event class' do
        expect(subject).to eq(Yes::Core::Event)
      end
    end
  end

  describe Yes::Core::EventClassResolver::SkipValidationProxy do
    subject { described_class.new(event_class) }

    let(:event_class) { Yes::Core::Event }

    describe '#new' do
      it 'creates an instance with skip_validation: true' do
        event = subject.new(type: 'TestEvent', data: {})
        expect(event).to be_a(Yes::Core::Event)
      end
    end
  end
end
