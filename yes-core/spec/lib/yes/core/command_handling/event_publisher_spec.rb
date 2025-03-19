# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::EventPublisher do
  subject(:event_publisher) do
    described_class.new(
      command:,
      aggregate_data: described_class::AggregateEventPublicationData.from_aggregate(aggregate),
      accessed_external_aggregates:,
      event_name:
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
  let(:command) { Test::User::Commands::ChangeLocation::Command.new(payload) }

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
      revision: -1
    }]
  end

  let(:event_name) { nil }

  before do
    PgEventstore::TestHelpers.clean_up_db

    Test::User::Aggregate.attribute :location, :aggregate, command: true
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
        expect(event.type).to eq('Test::UserLocationChanged')
        expect(event.data).to eq(command.payload.stringify_keys)
      end

      it 'includes metadata in the event' do
        event = event_publisher.call
        expect(event.metadata).to include(
          'origin' => 'test',
          'batch_id' => '123',
          'test' => 'value'
        )
      end
    end

    context 'when external revisions do not match' do
      let(:accessed_external_aggregates) do
        [{
          id: location_id,
          context: 'Test',
          name: 'Location',
          revision: 0 # actual is :no_stream (-1)
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

    context 'with explicit event name' do
      let(:event_name) { 'CustomLocationChanged' }

      before do
        stub_const('Test::User::Events::CustomLocationChanged',
                   Class.new(Yousty::Eventsourcing::Event) do
                     def schema
                       Dry::Schema.Params do
                         required(:user_id).value(Yousty::Api::Types::UUID)
                         required(:location_id).value(Yousty::Api::Types::UUID)
                       end
                     end
                   end)
      end

      it 'uses the explicit event name' do
        event = event_publisher.call

        aggregate_failures do
          expect(event).to be_a(PgEventstore::Event)
          expect(event.type).to eq('Test::UserCustomLocationChanged')
          expect(event.data).to eq(command.payload.stringify_keys)
        end
      end
    end
  end
end
