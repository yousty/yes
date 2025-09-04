# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::EventPublisher do
  subject(:event_publisher) do
    described_class.new(
      command:,
      aggregate_data: described_class::AggregateEventPublicationData.from_aggregate(aggregate),
      accessed_external_aggregates:
    )
  end

  let(:user_id) { SecureRandom.uuid }
  let(:location_id) { SecureRandom.uuid }
  let(:payload) do
    {
      user_id:,
      location_id:,
      origin: 'test',
      batch_id: '123',
      metadata: { 'test' => 'value' }
    }
  end
  let(:command) { Test::User::Commands::ChangeLocationId::Command.new(payload) }

  let(:aggregate) do
    Test::User::Aggregate.new(user_id)
  end

  let(:location) do
    Test::Location::Aggregate.new(location_id)
  end

  let(:accessed_external_aggregates) do
    [{
      id: location_id,
      context: 'Test',
      name: 'Location',
      revision: -> { -1 }
    }]
  end

  before do
    PgEventstore::TestHelpers.clean_up_db

    Test::User::Aggregate.attribute :location_id, :uuid, command: true
  end

  after do
    # Clean up location attribute
    Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                Test::User::Aggregate.attributes.except(:location))
  end

  describe '#call' do
    context 'when external revisions match' do
      it 'publishes the event' do
        event = event_publisher.call
        expect(event).to be_a(PgEventstore::Event)
        expect(event.type).to eq('Test::UserLocationIdChanged')
        expect(event.data).to eq(command.payload.stringify_keys)
      end

      it 'includes metadata in the event' do
        event = event_publisher.call
        expect(event.metadata).to include(
          'origin' => 'test',
          'batch_id' => '123',
          'test' => 'value',
          'yes-dsl' => true
        )
      end

      context 'with draft metadata' do
        let(:payload) do
          {
            user_id:,
            location_id:,
            origin: 'test',
            batch_id: '123',
            metadata: { test: 'value', draft: true }
          }
        end

        it 'publishes event to draft stream' do
          event = event_publisher.call
          
          # Verify the event was published
          expect(event).to be_a(PgEventstore::Event)
          
          # The event should have been published to UserDraft stream
          # We can verify this by checking the event's stream property
          expect(event.stream.stream_name).to eq('UserDraft')
          expect(event.type).to eq('Test::UserLocationIdChanged')
        end

        it 'preserves draft metadata in the event' do
          event = event_publisher.call
          expect(event.metadata).to include('draft' => true)
        end
      end
    end

    context 'when external revisions do not match' do
      let(:accessed_external_aggregates) do
        [{
          id: location_id,
          context: 'Test',
          name: 'Location',
          revision: -> { 0 }
        }]
      end

      it 'raises a WrongExpectedRevisionError' do
        expect { event_publisher.call }.to raise_error(PgEventstore::WrongExpectedRevisionError)
      end
    end

    context 'when aggregate revision does not match stream revision' do
      before do
        # Create an event in the stream to increment the revision
        stream = PgEventstore::Stream.new(
          context: 'Test',
          stream_name: 'User',
          stream_id: user_id
        )
        PgEventstore.client.append_to_stream(
          stream,
          PgEventstore::Event.new(type: 'Test::UserCreated', data: {})
        )
      end

      it 'raises a WrongExpectedRevisionError' do
        expect { event_publisher.call }.to raise_error(PgEventstore::WrongExpectedRevisionError)
      end
    end
  end

  describe '#stream_name (private method)' do
    subject { event_publisher.send(:stream_name, 'TestAggregate') }

    context 'when command has draft metadata' do
      let(:payload) do
        {
          user_id:,
          location_id:,
          metadata: { draft: true }
        }
      end

      it 'returns draft stream name' do
        expect(subject).to eq('TestAggregateDraft')
      end
    end

    context 'when command has edit_template_command metadata' do
      let(:payload) do
        {
          user_id:,
          location_id:,
          metadata: { edit_template_command: true }
        }
      end

      it 'returns edit template stream name' do
        expect(subject).to eq('TestAggregateEditTemplate')
      end
    end

    context 'when command has no draft metadata' do
      it 'returns original stream name' do
        expect(subject).to eq('TestAggregate')
      end
    end

    context 'when command has metadata but no draft flag' do
      let(:payload) do
        {
          user_id:,
          location_id:,
          metadata: { 'other' => 'value' }
        }
      end

      it 'returns original stream name' do
        expect(subject).to eq('TestAggregate')
      end
    end
  end

  describe 'external aggregate revision verification with draft mode' do
    context 'when main aggregate uses draft stream' do
      let(:payload) do
        {
          user_id:,
          location_id:,
          metadata: { 'draft' => true }
        }
      end

      let(:accessed_external_aggregates) do
        [{
          id: location_id,
          context: 'Test',
          name: 'Location',
          revision: -> { -1 }
        }]
      end

      it 'verifies external aggregates against their non-draft streams' do
        # This should succeed because external aggregates are checked against their normal streams
        expect { event_publisher.call }.not_to raise_error
      end

      it 'does not use draft stream names for external aggregate verification' do
        # Create a revision mismatch on the normal Location stream (not LocationDraft)
        location_stream = PgEventstore::Stream.new(
          context: 'Test',
          stream_name: 'Location',
          stream_id: location_id
        )
        PgEventstore.client.append_to_stream(
          location_stream,
          PgEventstore::Event.new(type: 'Test::LocationCreated', data: {})
        )

        # Now the external aggregate revision check should fail
        accessed_external_aggregates[0][:revision] = -> { -1 }
        
        expect { event_publisher.call }.to raise_error(PgEventstore::WrongExpectedRevisionError)
      end
    end
  end
end
