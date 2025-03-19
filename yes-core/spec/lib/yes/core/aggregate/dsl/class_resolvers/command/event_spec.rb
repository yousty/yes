# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command::Event do
  let(:aggregate_class) { Class.new }
  let(:command_data) do
    Yes::Core::Aggregate::Dsl::CommandData.new(
      :create_user,
      aggregate_class,
      context: 'UserManagement',
      aggregate: 'User',
      payload_attributes: {
        email: :string,
        name: :string
      }
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
  end
end
