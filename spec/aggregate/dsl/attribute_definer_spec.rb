# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::AttributeDefiner do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:user_id) { SecureRandom.uuid }
  let(:attribute_data) do
    Yes::Aggregate::DSL::AttributeData.new(attribute_name, attribute_type, aggregate_class, options)
  end

  describe '.define' do
    # define a new attribute on the existing user aggregate
    subject { described_class.new(attribute_data).call }

    it 'creates and registers command, event, and handler classes' do
      expect { subject }.to change {
        Test::User::Commands.const_defined?('ChangeTestField::Command')
      }.from(false).to(true).
        and change {
              Test::User::Events.const_defined?(:TestFieldChanged)
            }.from(false).to(true).
        and change {
              Test::User::Commands.const_defined?('ChangeTestField::Handler')
            }.from(false).to(true)
    end

    context 'change command method' do
      it 'defines a change method for the attribute' do
        subject
        expect(aggregate_class.new).to respond_to(:change_test_field)
      end
    end

    context 'can_change...? command method' do
      it 'defines a can_change...? method for the attribute' do
        subject
        expect(aggregate_class.new).to respond_to(:can_change_test_field?)
      end
    end

    context 'attribute accessor method' do
      it 'defines a reader method for the attribute' do
        subject
        expect(aggregate_class.new).to respond_to(:test_field)
      end
    end
  end
end
