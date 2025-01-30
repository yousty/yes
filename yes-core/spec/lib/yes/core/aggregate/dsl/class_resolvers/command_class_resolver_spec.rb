# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:user_id) { SecureRandom.uuid }
  let(:attribute_data) do
    Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class, options)
  end

  describe '#call' do
    subject { described_class.new(attribute_data).call }

    it 'resolves command class with correct attributes' do
      command_class = subject

      aggregate_failures do
        expect(command_class.superclass).to eq(Yes::Core::Command)
        expect(command_class.schema.key?(:user_id)).to be true
        expect(command_class.schema.key?(:test_field)).to be true
      end
    end

    it 'defines subject_id alias method' do
      command_class = subject
      command = command_class.new(user_id:, test_field: 'value')

      expect(command.subject_id).to eq(user_id)
    end

    it 'creates command class that properly handles attributes' do
      command_class = subject
      command = command_class.new(user_id:, test_field: 'Test Value')

      aggregate_failures do
        expect(command.respond_to?(:test_field)).to be true
        expect(command.test_field).to eq('Test Value')
      end
    end
  end
end
