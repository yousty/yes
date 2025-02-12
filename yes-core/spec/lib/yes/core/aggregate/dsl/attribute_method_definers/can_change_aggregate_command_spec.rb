# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::CanChangeAggregateCommand do
  subject { instance.call }

  let(:instance) { described_class.new(attribute_data) }
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :location }
  let(:attribute_type) { :aggregate }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:command_name) { :change_location }
  let(:attribute_data) do
    Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class, options)
  end

  before do
    Test::User::Aggregate.attribute :location, :aggregate
  end

  after do
    # Clean up location attribute
    Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                Test::User::Aggregate.attributes.except(:location))

    # Clean up configuration
    aggregate_classes = Yes::Core.configuration.instance_variable_get(:@aggregate_classes)
    aggregate_classes&.delete(context)
  end

  describe '#call' do
    let(:aggregate_instance) { aggregate_class.new }

    it 'defines a can_change method for the attribute' do
      subject
      expect(aggregate_instance).to respond_to(:can_change_location?)
    end

    it 'defines an error accessor' do
      subject
      expect(aggregate_instance).to respond_to(:change_location_error)
      expect(aggregate_instance).to respond_to(:change_location_error=)
    end

    describe '#can_change_location?' do
      subject { aggregate_instance.can_change_location?(**command_payload) }

      let(:guard_evaluator_class) { Test::User::Commands::ChangeLocation::GuardEvaluator }
      let(:guard_evaluator_instance) { instance_double(guard_evaluator_class) }
      let(:location_id) { SecureRandom.uuid }
      let(:location_aggregate) { instance_double('Test::Location::Aggregate', id: location_id) }
      let(:command_payload) { { location: location_aggregate } }

      let(:attribute_setup) do
        instance.call
      end

      before do
        attribute_setup

        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator_instance)
        allow(guard_evaluator_instance).to receive(:call).and_return(true)
        allow(guard_evaluator_instance).to receive(:accessed_external_aggregates).and_return([])
      end

      context 'when validation succeeds' do
        it 'returns true' do
          expect(subject).to be true
        end

        it 'clears any previous error' do
          aggregate_instance.change_location_error = 'Previous error'
          subject
          expect(aggregate_instance.change_location_error).to be_nil
        end
      end

      context 'when validation fails' do
        let(:error_message) { 'Validation failed' }

        before do
          allow(guard_evaluator_instance).to receive(:call).and_raise(
            Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition, error_message
          )
        end

        it 'returns false' do
          expect(subject).to be false
        end

        it 'sets the error message' do
          subject
          expect(aggregate_instance.change_location_error).to eq(error_message)
        end
      end

      context 'when no change is needed' do
        before do
          allow(guard_evaluator_instance).to receive(:call).and_raise(
            Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition, 'No change needed'
          )
        end

        it 'returns false' do
          expect(subject).to be false
        end
      end
    end
  end
end
