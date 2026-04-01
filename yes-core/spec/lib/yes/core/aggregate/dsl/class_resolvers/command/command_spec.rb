# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command::Command do
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

    it 'resolves command class with correct attributes' do
      command_class = subject

      aggregate_failures do
        expect(command_class.superclass).to eq(Yes::Core::Command)
        expect(command_class.schema.key?(:email)).to be true
        expect(command_class.schema.key?(:name)).to be true
      end
    end

    context 'command instance' do
      subject { super().new(payload) }

      let(:payload) { { user_id:, email:, name: } }
      let(:email) { 'test@example.com' }
      let(:name) { 'Test User' }

      context 'when command is valid' do
        let(:user_id) { SecureRandom.uuid }

        it 'creates command class that properly handles attributes' do
          command = subject

          aggregate_failures do
            expect(command.respond_to?(:email)).to be true
            expect(command.respond_to?(:name)).to be true
            expect(command.email).to eq('test@example.com')
            expect(command.name).to eq('Test User')
          end
        end
      end

      context 'when command is invalid' do
        let(:user_id) { 'invalid-uuid' }

        it 'raises an error' do
          expect { subject }.to raise_error(Yousty::Eventsourcing::Command::Invalid)
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

      it 'resolves command class with optional attributes' do
        command_class = subject

        aggregate_failures do
          expect(command_class.superclass).to eq(Yes::Core::Command)
          expect(command_class.schema.key?(:email)).to be true
          expect(command_class.schema.key?(:name)).to be true
          expect(command_class.schema.key?(:phone)).to be true
          expect(command_class.schema.key?(:age)).to be true
        end
      end

      context 'command instance with optional attributes' do
        subject { super().new(payload) }

        context 'when optional attributes are provided' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:phone) { '123456789' }
          let(:age) { 30 }
          let(:payload) { { user_id:, email:, name:, phone:, age: } }

          it 'handles optional attributes when provided' do
            command = subject

            aggregate_failures do
              expect(command.phone).to eq(phone)
              expect(command.age).to eq(age)
            end
          end
        end

        context 'when optional attributes are not provided' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:payload) { { user_id:, email:, name: } }

          it 'allows omitting optional attributes' do
            command = subject

            aggregate_failures do
              expect(command.phone).to be_nil
              expect(command.age).to be_nil
            end
          end
        end
      end
    end

    context 'with nil values on non-nullable required attributes' do
      let(:user_id) { SecureRandom.uuid }

      context 'when nil is passed for a required string attribute' do
        subject { super().new(user_id:, email: nil, name: 'Test User') }

        it 'raises an error' do
          expect { subject }.to raise_error(Yousty::Eventsourcing::Command::Invalid)
        end
      end

      context 'when nil is passed for a required integer attribute' do
        let(:payload_attributes) do
          {
            email: :string,
            age: :integer
          }
        end

        subject { super().new(user_id:, email: 'test@example.com', age: nil) }

        it 'raises an error' do
          expect { subject }.to raise_error(Yousty::Eventsourcing::Command::Invalid)
        end
      end

      context 'when nil is passed for a required float attribute' do
        let(:payload_attributes) do
          {
            email: :string,
            score: :float
          }
        end

        subject { super().new(user_id:, email: 'test@example.com', score: nil) }

        it 'raises an error' do
          expect { subject }.to raise_error(Yousty::Eventsourcing::Command::Invalid)
        end
      end
    end

    context 'with nullable attributes' do
      let(:payload_attributes) do
        {
          email: :string,
          role: { type: :string, nullable: true }
        }
      end

      context 'command instance' do
        subject { super().new(payload) }

        let(:user_id) { SecureRandom.uuid }

        context 'when nil is passed for a nullable attribute' do
          let(:payload) { { user_id:, email: 'test@example.com', role: nil } }

          it 'accepts nil and stores it as nil' do
            aggregate_failures do
              expect(subject.role).to be_nil
              expect(subject.email).to eq('test@example.com')
            end
          end
        end

        context 'when a valid value is passed for a nullable attribute' do
          let(:payload) { { user_id:, email: 'test@example.com', role: 'admin' } }

          it 'accepts and stores the value' do
            expect(subject.role).to eq('admin')
          end
        end

        context 'when nullable attribute is omitted entirely' do
          let(:payload) { { user_id:, email: 'test@example.com' } }

          it 'raises an error because the key is required' do
            expect { subject }.to raise_error(Yousty::Eventsourcing::Command::Invalid)
          end
        end
      end
    end
  end
end
