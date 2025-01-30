# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Handler do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:attribute_data) do
    Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class, options)
  end

  describe '#call' do
    subject { described_class.new(attribute_data).call }

    it 'resolves handler class with correct event name' do
      expect(subject.event_name).to eq('TestFieldChanged')
    end

    it 'defines check method for no-change validation' do
      expect(subject.instance_methods).to include(:check_test_field_is_not_changing)
    end

    it 'resolves handler class inheriting from Yes::Core::CommandHandler' do
      expect(subject.superclass).to eq(Yes::Core::CommandHandler)
    end

    it 'defines a call method' do
      expect(subject.instance_methods(false)).to include(:call)
    end
  end
end
