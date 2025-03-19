# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::Event do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:user_id) { SecureRandom.uuid }
  let(:test_field) { 'value' }
  let(:attribute_data) do
    Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class, options)
  end

  describe '#call' do
    subject { described_class.new(attribute_data).call }

    it 'resolves event class with correct schema' do
      event = subject.new(data: { user_id:, test_field: })

      expect(event.schema.rules.keys).to include(:user_id, :test_field)
    end

    it 'resolves event class inheriting from Yes::Core::Event' do
      expect(subject.superclass).to eq(Yes::Core::Event)
    end

    it 'creates event class that properly handles event data' do
      event = subject.new(data: { user_id: SecureRandom.uuid, test_field: 'New Value' })
      expect(event.data[:test_field]).to eq('New Value')
    end
  end
end
