# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::CanChangeCommand do
  subject { instance.call }

  let(:instance) { described_class.new(attribute_data) }
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:command_payload) { { test_field: 'test value' } }
  let(:guard_evaluator_class) { Test::User::Commands::ChangeTestField::GuardEvaluator }
  let(:aggregate_instance) { aggregate_class.new }
  let(:command_name) { :change_test_field }
  let(:attribute_data) { Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class) }

  before do
    Test::User::Aggregate.attribute :test_field, :string
  end

  after do
    # Clean up location attribute
    Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                Test::User::Aggregate.attributes.except(:test_field))
  end

  describe '#call' do
    before do
      subject
    end

    it 'defines a can_change method for the attribute' do
      expect(aggregate_instance).to respond_to(:can_change_test_field?)
    end

    it 'defines an error accessor' do
      expect(aggregate_instance).to respond_to(:change_test_field_error)
      expect(aggregate_instance).to respond_to(:change_test_field_error=)
    end

    context 'when validation succeeds' do
      let(:guard_evaluator_instance) { instance_double(guard_evaluator_class, call: true) }

      before do
        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator_instance)
        allow(guard_evaluator_instance).to receive(:accessed_external_aggregates).and_return([])
      end

      it 'returns true' do
        expect(aggregate_instance.can_change_test_field?(**command_payload)).to be true
      end

      it 'clears any previous error' do
        aggregate_instance.change_test_field_error = 'Previous error'
        aggregate_instance.can_change_test_field?(**command_payload)
        expect(aggregate_instance.change_test_field_error).to be_nil
      end
    end

    context 'when validation fails' do
      let(:error_message) { 'Validation failed' }
      let(:guard_evaluator_instance) { instance_double(guard_evaluator_class) }

      before do
        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator_instance)
        allow(guard_evaluator_instance).to receive(:accessed_external_aggregates).and_return([])
        allow(guard_evaluator_instance).to receive(:call).and_raise(
          Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition, error_message
        )
      end

      it 'returns false' do
        expect(aggregate_instance.can_change_test_field?(**command_payload)).to be false
      end

      it 'sets the error message' do
        aggregate_instance.can_change_test_field?(**command_payload)
        expect(aggregate_instance.change_test_field_error).to eq(error_message)
      end
    end
  end
end
