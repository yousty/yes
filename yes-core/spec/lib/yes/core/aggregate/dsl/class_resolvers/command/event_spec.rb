# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command::Event do
  let(:aggregate_class) { Class.new }
  let(:payload_attributes) do
    {
      email: :string,
      name: :string
    }
  end
  let(:command_data) do
    Yes::Core::Aggregate::Dsl::CommandData.new(
      :create_user,
      aggregate_class,
      context: 'UserManagement',
      aggregate: 'User',
      payload_attributes: payload_attributes
    )
  end

  describe '#call' do
    subject { described_class.new(command_data).call }

    let(:data) { { user_id:, email:, name: } }

    let(:user_id) { SecureRandom.uuid }
    let(:email) { 'test@example.com' }
    let(:name) { 'Test User' }

    it 'resolves event class inheriting from Yes::Core::Event' do
      expect(subject.superclass).to eq(Yes::Core::Event)
    end

    context 'event instance' do
      subject { super().new(data:) }

      it 'resolves event class with correct schema' do
        event = subject

        expect(event.schema.rules.keys).to include(:user_id, :email, :name)
      end

      it 'creates event class that properly handles event data' do
        event = subject

        aggregate_failures do
          expect(event.data[:user_id]).to eq(user_id)
          expect(event.data[:email]).to eq(email)
          expect(event.data[:name]).to eq(name)
        end
      end
    end

    context 'with optional attributes' do
      let(:payload_attributes) do
        {
          email: :string,
          name: :string,
          phone: { type: :string, optional: true },
          age: { type: :integer, optional: true }
        }
      end

      it 'resolves event class with schema supporting optional attributes' do
        event_class = subject
        event_schema = event_class.new.schema

        aggregate_failures do
          # Required attributes
          expect(event_schema.rules[:user_id].required?).to be true
          expect(event_schema.rules[:email].required?).to be true
          expect(event_schema.rules[:name].required?).to be true

          # Optional attributes
          expect(event_schema.rules[:phone].required?).to be false
          expect(event_schema.rules[:age].required?).to be false
        end
      end

      context 'event instance with optional attributes' do
        context 'when optional attributes are provided' do
          let(:data) { { user_id:, email:, name:, phone: '123456789', age: 30 } }

          subject { super().new(data:) }

          it 'handles optional attributes when provided' do
            event = subject

            aggregate_failures do
              expect(event.data[:phone]).to eq('123456789')
              expect(event.data[:age]).to eq(30)
            end
          end
        end

        context 'when optional attributes are not provided' do
          let(:data) { { user_id:, email:, name: } }

          subject { super().new(data:) }

          it 'allows omitting optional attributes' do
            event = subject

            aggregate_failures do
              expect(event.data).not_to include(:phone)
              expect(event.data).not_to include(:age)
            end
          end
        end
      end
    end
  end
end
