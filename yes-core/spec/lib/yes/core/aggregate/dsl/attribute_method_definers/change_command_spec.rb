# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::ChangeCommand do
  subject { instance.call }

  let(:instance) { described_class.new(attribute_data) }
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:command_name) { :change_test_field }
  let(:attribute_data) { Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class) }

  before do
    Test::User::Aggregate.attribute :test_field, :string, command: true
  end

  after do
    # Clean up location attribute
    Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                Test::User::Aggregate.attributes.except(:test_field))
  end

  describe '#call' do
    let(:aggregate_instance) { aggregate_class.new }

    it 'defines a change method for the attribute' do
      subject
      expect(aggregate_instance).to respond_to(:change_test_field)
    end

    describe '#change_test_field' do
      subject { aggregate_instance.change_test_field(command_payload) }

      let(:guard_evaluator_class) { Test::User::Commands::ChangeTestField::GuardEvaluator }
      let(:guard_evaluator_instance) { instance_double(guard_evaluator_class) }
      let(:new_value) { 'New Value' }

      let(:attribute_setup) do
        instance.call
      end

      before do
        attribute_setup

        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator_instance)
        allow(guard_evaluator_instance).to receive(:call).and_return(true)
        allow(guard_evaluator_instance).to receive(:accessed_external_aggregates).and_return([])
      end

      shared_examples 'a command that updates the test_field' do
        it 'instantiates and calls the guard evaluator with the command' do
          subject
          expect(guard_evaluator_instance).to have_received(:call)
        end

        it 'updates the read model' do
          subject
          expect(aggregate_instance.test_field).to eq(new_value)
        end
      end

      context 'when using hash payload' do
        let(:command_payload) { { test_field: new_value } }

        it_behaves_like 'a command that updates the test_field'
      end

      context 'when using shorthand value payload' do
        let(:command_payload) { new_value }

        it_behaves_like 'a command that updates the test_field'
      end
    end
  end
end
