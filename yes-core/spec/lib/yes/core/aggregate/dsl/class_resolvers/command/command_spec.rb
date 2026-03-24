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
          expect { subject }.to raise_error(Yes::Core::Command::Invalid)
        end
      end
    end

    context 'with nil values on non-nullable required string attributes' do
      let(:user_id) { SecureRandom.uuid }

      context 'when nil is passed for a required string attribute' do
        subject { super().new(user_id:, email: nil, name: 'Test User') }

        it 'raises an error instead of silently coercing nil to empty string' do
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

        context 'when optional non-nullable attributes are explicitly passed as nil' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:payload) { { user_id:, email:, name:, phone: nil } }

          it 'raises an error instead of silently coercing nil' do
            expect { subject }.to raise_error(Yousty::Eventsourcing::Command::Invalid)
          end
        end
      end
    end

    context 'with nullable attributes' do
      let(:payload_attributes) do
        {
          email: :string,
          name: :string,
          phone: { type: :string, nullable: true },
          age: { type: :integer, nullable: true }
        }
      end

      it 'resolves command class with nullable attributes' do
        command_class = subject

        aggregate_failures do
          expect(command_class.superclass).to eq(Yes::Core::Command)
          expect(command_class.schema.key?(:email)).to be true
          expect(command_class.schema.key?(:name)).to be true
          expect(command_class.schema.key?(:phone)).to be true
          expect(command_class.schema.key?(:age)).to be true
        end
      end

      context 'command instance with nullable attributes' do
        subject { super().new(payload) }

        context 'when nullable attributes are provided with values' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:phone) { '123456789' }
          let(:age) { 30 }
          let(:payload) { { user_id:, email:, name:, phone:, age: } }

          it 'handles nullable attributes when provided with values' do
            command = subject

            aggregate_failures do
              expect(command.phone).to eq(phone)
              expect(command.age).to eq(age)
            end
          end
        end

        context 'when nullable attributes are provided as nil' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:payload) { { user_id:, email:, name:, phone: nil, age: nil } }

          it 'allows nullable attributes to be nil' do
            command = subject

            aggregate_failures do
              expect(command.phone).to be_nil
              expect(command.age).to be_nil
            end
          end
        end
      end
    end

    context 'with optional and nullable attributes' do
      let(:payload_attributes) do
        {
          email: :string,
          name: :string,
          phone: { type: :string, optional: true, nullable: true },
          age: { type: :integer, optional: true, nullable: false }
        }
      end

      it 'resolves command class with optional and nullable attributes' do
        command_class = subject

        aggregate_failures do
          expect(command_class.superclass).to eq(Yes::Core::Command)
          expect(command_class.schema.key?(:email)).to be true
          expect(command_class.schema.key?(:name)).to be true
          expect(command_class.schema.key?(:phone)).to be true
          expect(command_class.schema.key?(:age)).to be true
        end
      end

      context 'command instance with optional and nullable attributes' do
        subject { super().new(payload) }

        context 'when optional nullable attribute is omitted' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:payload) { { user_id:, email:, name: } }

          it 'allows omitting optional nullable attributes' do
            command = subject

            aggregate_failures do
              expect(command.phone).to be_nil
              expect(command.age).to be_nil
            end
          end
        end

        context 'when optional nullable attribute is provided as nil' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:payload) { { user_id:, email:, name:, phone: nil } }

          it 'allows optional nullable attributes to be explicitly nil' do
            command = subject

            expect(command.phone).to be_nil
          end
        end

        context 'when optional nullable attribute is provided with value' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:phone) { '123456789' }
          let(:payload) { { user_id:, email:, name:, phone: } }

          it 'handles optional nullable attributes when provided with values' do
            command = subject

            expect(command.phone).to eq(phone)
          end
        end
      end
    end

    context 'with explicitly required attributes (optional: false)' do
      let(:payload_attributes) do
        {
          email: :string,
          name: :string,
          phone: { type: :string, optional: false },
          age: { type: :integer, optional: false }
        }
      end

      context 'command instance with explicitly required attributes' do
        subject { super().new(payload) }

        context 'when required attributes are provided' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:phone) { '123456789' }
          let(:age) { 30 }
          let(:payload) { { user_id:, email:, name:, phone:, age: } }

          it 'handles explicitly required attributes when provided' do
            command = subject

            aggregate_failures do
              expect(command.phone).to eq(phone)
              expect(command.age).to eq(age)
            end
          end
        end

        context 'when required attributes are omitted' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:payload) { { user_id:, email:, name: } }

          it 'raises validation error when explicitly required attributes are missing' do
            expect { subject }.to raise_error(Yes::Core::Command::Invalid)
          end
        end
      end
    end

    context 'with explicitly non-nullable attributes (nullable: false)' do
      let(:payload_attributes) do
        {
          email: :string,
          name: :string,
          phone: { type: :string, nullable: false },
          age: { type: :integer, nullable: false }
        }
      end

      context 'command instance with explicitly non-nullable attributes' do
        subject { super().new(payload) }

        context 'when non-nullable attributes are provided with values' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:phone) { '123456789' }
          let(:age) { 30 }
          let(:payload) { { user_id:, email:, name:, phone:, age: } }

          it 'handles explicitly non-nullable attributes when provided with values' do
            command = subject

            aggregate_failures do
              expect(command.phone).to eq(phone)
              expect(command.age).to eq(age)
            end
          end
        end

        context 'when non-nullable attributes are provided as nil' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:payload) { { user_id:, email:, name:, phone: nil, age: nil } }

          it 'raises validation error when explicitly non-nullable attributes are nil' do
            expect { subject }.to raise_error(Yes::Core::Command::Invalid)
          end
        end
      end
    end

    context 'with optional: false and nullable: false' do
      let(:payload_attributes) do
        {
          email: :string,
          name: :string,
          phone: { type: :string, optional: false, nullable: false },
          age: { type: :integer, optional: false, nullable: false }
        }
      end

      context 'command instance with required non-nullable attributes' do
        subject { super().new(payload) }

        context 'when attributes are provided with values' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:phone) { '123456789' }
          let(:age) { 30 }
          let(:payload) { { user_id:, email:, name:, phone:, age: } }

          it 'handles required non-nullable attributes when provided with values' do
            command = subject

            aggregate_failures do
              expect(command.phone).to eq(phone)
              expect(command.age).to eq(age)
            end
          end
        end

        context 'when attributes are omitted' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:payload) { { user_id:, email:, name: } }

          it 'raises validation error when required non-nullable attributes are missing' do
            expect { subject }.to raise_error(Yes::Core::Command::Invalid)
          end
        end

        context 'when attributes are provided as nil' do
          let(:user_id) { SecureRandom.uuid }
          let(:email) { 'test@example.com' }
          let(:name) { 'Test User' }
          let(:payload) { { user_id:, email:, name:, phone: nil, age: nil } }

          it 'raises validation error when required non-nullable attributes are nil' do
            expect { subject }.to raise_error(Yes::Core::Command::Invalid)
          end
        end
      end
    end
  end
end
