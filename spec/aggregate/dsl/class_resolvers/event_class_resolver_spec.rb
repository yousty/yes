# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::ClassResolvers::Event do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:user_id) { SecureRandom.uuid }
  let(:test_field) { 'value' }
  let(:attribute) { Yes::Aggregate::DSL::Attribute.new(attribute_name, attribute_type, aggregate_class, options) }

  describe '#call' do
    subject { described_class.new(attribute).call }

    it 'resolves event class with correct schema' do
      event = subject.new(data: { user_id:, test_field: })

      expect(event.schema.rules.keys).to include(:user_id, :test_field)
    end

    it 'resolves event class inheriting from Yes::Event' do
      expect(subject.superclass).to eq(Yes::Event)
    end

    it 'creates event class that properly handles event data' do
      event = subject.new(data: { user_id: SecureRandom.uuid, test_field: 'New Value' })
      expect(event.data[:test_field]).to eq('New Value')
    end
  end
end 