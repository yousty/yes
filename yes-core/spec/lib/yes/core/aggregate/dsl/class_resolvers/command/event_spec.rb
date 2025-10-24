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

  after do
    # Clean up constants to ensure test isolation
    Object.send(:remove_const, 'UserManagement') if Object.const_defined?(:UserManagement)
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

      context 'schema' do
        let(:result_with_all) { subject.new(data: { user_id:, email:, name:, phone: '123456789', age: 30 }) }
        let(:result_required_only) { subject.new(data: { user_id:, email:, name: }) }

        it 'resolves event class with schema supporting optional attributes' do
          aggregate_failures do
            expect(result_with_all.data).to include(:phone, :age)
            expect(result_required_only.data).not_to include(:phone, :age)
          end
        end
      end

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

    context 'with encrypted attributes' do
      let(:payload_attributes) do
        {
          email: :string,
          name: :string,
          ssn: :string
        }
      end

      before do
        # Mark ssn as encrypted in command_data
        command_data.encrypted_attributes = [:ssn]
      end

      it 'generates event class with encryption_schema class method' do
        expect(subject).to respond_to(:encryption_schema)
      end

      it 'encryption_schema returns correct structure' do
        schema = subject.encryption_schema

        aggregate_failures do
          expect(schema[:key]).to be_a(Proc)
          expect(schema[:attributes]).to eq([:ssn])
        end
      end

      it 'encryption_schema key lambda returns aggregate_id from data' do
        schema = subject.encryption_schema
        data = { user_id: user_id, email: 'test@example.com', name: 'Test', ssn: '123-45-6789' }

        expect(schema[:key].call(data)).to eq(user_id)
      end

      context 'event instance' do
        subject { super().new(data: { user_id:, email:, name:, ssn: '123-45-6789' }) }

        it 'creates event instance successfully with encrypted attribute' do
          expect(subject.data[:ssn]).to eq('123-45-6789')
        end
      end
    end

    context 'without encrypted attributes' do
      it 'does not define encryption_schema class method' do
        expect(subject).not_to respond_to(:encryption_schema)
      end
    end
  end
end
