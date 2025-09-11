# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::StateUpdater do
  subject(:state_updater) { described_class.new(payload:, aggregate:) }

  let(:payload) { { location_id:, name: 'John Doe' } }
  let(:location_id) { SecureRandom.uuid }
  let(:location) { Test::Location::Aggregate.new(location_id) }
  let(:aggregate) { Test::User::Aggregate.new }

  before do
    Test::User::Aggregate.attribute :location_id, :uuid, command: true
    Test::User::Aggregate.attribute :name, :string, command: true
    aggregate.change_location_id(location_id:)
  end

  after do
    # Clean up attributes and state update blocks
    Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                Test::User::Aggregate.attributes.except(:location_id,
                                                                                                        :name))
    described_class.instance_variable_set(:@update_state_block, nil)
    described_class.instance_variable_set(:@updated_attributes, [])
  end

  describe '.update_state' do
    it 'registers the update state block' do
      described_class.update_state { name { 'Jane Doe' } }
      expect(described_class.update_state_block).to be_a(Proc)
    end

    it 'analyzes the block for updated attributes' do
      described_class.update_state do
        name { 'Jane Doe' }
        email { 'jane@example.com' }
      end

      expect(described_class.updated_attributes).to match_array(%i[name email])
    end
  end

  describe '#call' do
    context 'with update state block' do
      before do
        described_class.update_state do
          name { "#{payload[:name]} Jr." }
        end
      end

      it 'returns the updated attributes with their new values' do
        expect(state_updater.call).to eq(
          name: 'John Doe Jr.'
        )
      end
    end

    context 'without update state block' do
      it 'returns the payload without aggregate_id' do
        expect(state_updater.call).to eq(
          location_id: location_id,
          name: 'John Doe'
        )
      end
    end
  end

  describe 'state update evaluation context' do
    context 'when accessing via aggregate attribute' do
      before do
        Test::User::Aggregate.parent :location
        
        described_class.update_state do
          name { location.id }
        end
      end

      it 'can access aggregate attributes' do
        expect(state_updater.call).to eq(
          name: location_id
        )
      end
    end

    context 'when accessing payload methods' do
      context 'when accessing via payload hash' do
        before do
          described_class.update_state do
            name { payload[:name].upcase }
          end
        end

        it 'has access to payload methods' do
          expect(state_updater.call).to eq(name: 'JOHN DOE')
        end
      end

      context 'when accessing via payload aggregate attribute' do
        before do
          described_class.update_state do
            name { payload.location.id }
          end
        end

        it 'can access payload aggregate attributes' do
          expect(state_updater.call).to eq(
            name: location_id
          )
        end
      end
    end

    context 'when accessing aggregate methods' do
      before do
        described_class.update_state do
          name { "#{name} Jr." }
        end
      end

      it 'delegates methods to the aggregate' do
        expect(aggregate).to receive(:name).and_return('John Doe')
        expect(state_updater.call).to eq(name: 'John Doe Jr.')
      end
    end

    context 'when accessing event metadata' do
      subject(:state_updater) { described_class.new(payload:, aggregate:, event:) }

      let(:event) { double('Event', metadata: { 'creator' => 'admin', 'timestamp' => '2023-10-15' }) }

      before do
        described_class.update_state do
          name { event.metadata['creator'] }
          created_at { event.metadata['timestamp'] }
        end
      end

      it 'can access event metadata in the update block' do
        expect(state_updater.call).to eq(
          name: 'admin',
          created_at: '2023-10-15'
        )
      end
    end
  end
end
