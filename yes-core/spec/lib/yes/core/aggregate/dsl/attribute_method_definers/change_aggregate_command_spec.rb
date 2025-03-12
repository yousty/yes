# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::ChangeAggregateCommand do
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
  end

  describe '#call' do
    let(:aggregate_instance) { aggregate_class.new }

    it 'defines a change method for the attribute' do
      subject
      expect(aggregate_instance).to respond_to(:change_location)
    end

    describe '#change_location' do
      subject { aggregate_instance.change_location(command_payload) }

      let(:guard_evaluator_class) { Test::User::Commands::ChangeLocation::GuardEvaluator }
      let(:guard_evaluator_instance) { instance_double(guard_evaluator_class) }
      let(:location_id) { SecureRandom.uuid }
      let(:location_aggregate) { instance_double('Test::Location::Aggregate', id: location_id) }

      let(:attribute_setup) do
        instance.call
      end

      before do
        attribute_setup

        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator_instance)
        allow(guard_evaluator_instance).to receive(:call).and_return(true)
        allow(guard_evaluator_instance).to receive(:accessed_external_aggregates).and_return([])
      end

      shared_examples 'a command that updates the location' do
        it 'instantiates and calls the guard evaluator with the command' do
          subject
          expect(guard_evaluator_instance).to have_received(:call)
        end

        it 'updates the read model with the aggregate ID' do
          subject
          expect(aggregate_instance.location_id).to eq(location_id)
        end
      end

      context 'when using hash payload' do
        let(:command_payload) { { location: location_aggregate } }

        it_behaves_like 'a command that updates the location'
      end

      context 'when using shorthand value payload' do
        let(:command_payload) { location_aggregate }

        it_behaves_like 'a command that updates the location'
      end

      context 'when the guard evaluator raises an error' do
        before do
          allow(guard_evaluator_instance).to receive(:call).
            and_raise(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition, 'test error')
        end

        it 'does not update the read model' do
          original_id = aggregate_instance.location_id
          expect(aggregate_instance.location_id).to eq(original_id)
        end
      end
    end
  end
end
