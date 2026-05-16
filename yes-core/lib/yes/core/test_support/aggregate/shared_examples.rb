# frozen_string_literal: true

RSpec.shared_context 'with given events' do
  before do
    given_events.each do |event_data|
      event = event_instance(event_data)
      stream = event_stream(event_data)
      append_event(stream, event)
    end
  end
end

RSpec.shared_examples 'successful command' do
  let(:event) { aggregate.events.map(&:last).last }
  let(:expected_event_metadata) { nil }

  it 'correctly changes the aggregate state' do
    if success_attributes.any?
      expect { subject }.to change {
        aggregate.read_model.attributes.to_h.symbolize_keys.slice(*success_attributes.keys)
      }.to(success_attributes)
    end
  end

  it 'publishes expected event' do
    subject
    aggregate_failures do
      expect(event.type).to eq(expected_event_type)
      expect(event.data).to eq(expected_event_data.deep_stringify_keys)
      expect(event.metadata).to include(expected_event_metadata.deep_stringify_keys) if expected_event_metadata
    end
  end
end

RSpec.shared_examples 'invalid transition' do
  it 'raises InvalidTransition error' do
    expect(subject.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)
  end

  it 'does not change the aggregate state' do
    success_attributes.each_key do |attribute|
      expect { subject }.not_to(change { aggregate.public_send(attribute) })
    end
  end

  it 'does not publish event' do
    expect { subject }.not_to(
      change do
        aggregate.events.map(&:flatten).flatten.count
      rescue PgEventstore::StreamNotFoundError
        nil
      end
    )
  end
end

RSpec.shared_examples 'no change transition' do
  it 'raises NoChangeTransition error' do
    expect(subject.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition)
  end

  it 'does not change the aggregate state' do
    success_attributes.each_key do |attribute|
      expect { subject }.not_to(change { aggregate.public_send(attribute) })
    end
  end

  it 'does not publish event' do
    expect { subject }.not_to(
      change do
        aggregate.events.map(&:flatten).flatten.count
      rescue PgEventstore::StreamNotFoundError
        nil
      end
    )
  end
end

RSpec.shared_examples 'successful command group' do
  it 'returns a successful CommandGroupResponse' do
    expect(subject).to be_a(Yes::Core::Commands::CommandGroupResponse)
    expect(subject).to be_success
  end

  it 'publishes one event per sub-command in declaration order' do
    expect(subject.events.map(&:type)).to eq(expected_event_types)
  end

  it 'reflects the cumulative state on the read model' do
    if success_attributes.any?
      expect { subject }.to change {
        aggregate.read_model.reload.attributes.to_h.symbolize_keys.slice(*success_attributes.keys)
      }.to(success_attributes)
    end
  end
end

RSpec.shared_examples 'invalid command group transition' do
  it 'returns an InvalidTransition error and no events' do
    aggregate_failures do
      expect(subject).not_to be_success
      expect(subject.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)
      expect(subject.events).to be_empty
    end
  end

  it 'does not change the aggregate state' do
    success_attributes.each_key do |attribute|
      expect { subject }.not_to(change { aggregate.public_send(attribute) })
    end
  end
end

RSpec.shared_examples 'no change command group transition' do
  it 'returns a NoChangeTransition error and no events' do
    aggregate_failures do
      expect(subject).not_to be_success
      expect(subject.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition)
      expect(subject.events).to be_empty
    end
  end
end
