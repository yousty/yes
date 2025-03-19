# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command::Command do
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
  end
end
