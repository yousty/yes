# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::SharedReadModelRebuilder do
  let(:read_model_class) { SharedProfileReadModel }
  let(:profile_id) { SecureRandom.uuid }
  let(:ids) { [profile_id] }
  let(:rebuilder) { described_class.new(read_model_class, ids) }

  describe '#initialize' do
    subject { rebuilder }

    it 'assigns the read model class' do
      expect(subject.instance_variable_get(:@read_model_class)).to eq(read_model_class)
    end

    it 'assigns the ids' do
      expect(subject.instance_variable_get(:@ids)).to eq(ids)
    end

    it 'finds aggregates using the read model' do
      aggregate_types = subject.instance_variable_get(:@aggregate_types)
      aggregate_failures do
        expect(aggregate_types).to include(%w[Test PersonalInfo])
        expect(aggregate_types).to include(%w[Test ContactInfo])
      end
    end
  end

  describe '#call' do
    subject { rebuilder.call }

    before do
      # Clean up any existing read models
      SharedProfileReadModel.where(id: profile_id).destroy_all

      personal_info = Test::PersonalInfo::Aggregate.new(profile_id)
      personal_info.change_name(
        first_name: 'John',
        last_name: 'Doe'
      )

      personal_info.change_email(
        email: 'john.doe@example.com'
      )

      contact_info = Test::ContactInfo::Aggregate.new(profile_id)
      contact_info.change_city(city: 'New York')
      contact_info.change_address(
        address: '123 Main St',
        city: 'New York',
        postal_code: '10001',
        country: 'USA'
      )
    end

    it 'removes existing read models and rebuilds them' do
      SharedProfileReadModel.find(profile_id).update(first_name: 'Old')

      subject

      # The read model should be rebuilt with new data
      read_model = SharedProfileReadModel.find(profile_id)
      expect(read_model.first_name).to eq('John')
    end

    it 'rebuilds the read model with data from both aggregates' do
      subject

      read_model = SharedProfileReadModel.find(profile_id)

      aggregate_failures do
        # Data from PersonalInfo aggregate
        expect(read_model.first_name).to eq('John')
        expect(read_model.last_name).to eq('Doe')
        expect(read_model.email).to eq('john.doe@example.com')

        # Data from ContactInfo aggregate
        expect(read_model.address).to eq('123 Main St')
        expect(read_model.city).to eq('New York')
        expect(read_model.postal_code).to eq('10001')
        expect(read_model.country).to eq('USA')

        # Revision should reflect the number of events
        expect(read_model.test_personal_info_revision).to eq(1)
        expect(read_model.test_contact_info_revision).to eq(1)
      end
    end

    it 'processes events in chronological order' do
      # Add another email change after the initial setup
      personal_info = Test::PersonalInfo::Aggregate.new(profile_id)
      personal_info.change_email(email: 'new.email@example.com')

      subject

      read_model = SharedProfileReadModel.find(profile_id)
      # Should have the latest email
      expect(read_model.email).to eq('new.email@example.com')
    end

    context 'with multiple IDs' do
      let(:second_profile_id) { SecureRandom.uuid }
      let(:ids) { [profile_id, second_profile_id] }

      before do
        # Create events for the second profile
        second_personal_info = Test::PersonalInfo::Aggregate.new(second_profile_id)
        second_personal_info.change_name(first_name: 'Jane', last_name: 'Smith')

        second_contact_info = Test::ContactInfo::Aggregate.new(second_profile_id)
        second_contact_info.change_city(city: 'Los Angeles')
      end

      it 'rebuilds read models for all provided IDs' do
        subject

        aggregate_failures do
          first_profile = SharedProfileReadModel.find(profile_id)
          expect(first_profile.first_name).to eq('John')
          expect(first_profile.city).to eq('New York')

          second_profile = SharedProfileReadModel.find(second_profile_id)
          expect(second_profile.first_name).to eq('Jane')
          expect(second_profile.city).to eq('Los Angeles')
        end
      end
    end
  end

  describe 'EventWithAggregate' do
    let(:event) do
      # Create a real event from the event store
      personal_info = Test::PersonalInfo::Aggregate.new(profile_id)
      personal_info.change_name(first_name: 'Test', last_name: 'User')

      # Retrieve the event from the aggregate
      personal_info.events.to_a.flatten.first
    end
    let(:aggregate) { Test::PersonalInfo::Aggregate.new(profile_id) }
    let(:event_with_aggregate) { described_class::EventWithAggregate.new(event: event, aggregate: aggregate) }

    it 'stores event and aggregate' do
      aggregate_failures do
        expect(event_with_aggregate.event).to eq(event)
        expect(event_with_aggregate.aggregate).to eq(aggregate)
      end
    end

    it 'delegates created_at to event' do
      expect(event_with_aggregate.created_at).to eq(event.created_at)
    end
  end
end
