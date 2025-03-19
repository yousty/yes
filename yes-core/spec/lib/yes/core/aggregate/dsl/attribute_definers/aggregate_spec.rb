# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiners::Aggregate do
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
    Test::User::Aggregate.attribute :location, :aggregate, command: true
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

    it 'defines both can_change methods' do
      subject
      aggregate_failures do
        expect(aggregate_instance).to respond_to(:can_change_location?)
        expect(aggregate_instance).to respond_to(:can_change_location_id?)
      end
    end

    describe '#change_location' do
      subject { aggregate_instance.change_location(location:) }

      let(:guard_evaluator_class) { Test::User::Commands::ChangeLocation::GuardEvaluator }
      let(:guard_evaluator_instance) { instance_double(guard_evaluator_class) }
      let(:location_id) { SecureRandom.uuid }
      let(:location) { instance_double('Test::Location::Aggregate', id: location_id) }

      let(:attribute_setup) do
        instance.call
      end

      before do
        attribute_setup

        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator_instance)
        allow(guard_evaluator_instance).to receive(:call).and_return(true)
        allow(guard_evaluator_instance).to receive(:accessed_external_aggregates).and_return([])
      end

      it 'instantiates and calls the guard evaluator with the command' do
        subject
        expect(guard_evaluator_instance).to have_received(:call)
      end

      it 'updates the read model with the aggregate ID' do
        subject
        expect(aggregate_instance.location_id).to eq(location_id)
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

    describe '#change_location_id' do
      subject { aggregate_instance.change_location_id(location_id:) }

      let(:guard_evaluator_class) { Test::User::Commands::ChangeLocation::GuardEvaluator }
      let(:guard_evaluator_instance) { instance_double(guard_evaluator_class) }
      let(:location_id) { SecureRandom.uuid }

      let(:attribute_setup) do
        instance.call
      end

      before do
        attribute_setup

        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator_instance)
        allow(guard_evaluator_instance).to receive(:call).and_return(true)
        allow(guard_evaluator_instance).to receive(:accessed_external_aggregates).and_return([])
      end

      it 'instantiates and calls the guard evaluator with the command' do
        subject
        expect(guard_evaluator_instance).to have_received(:call)
      end

      it 'updates the read model with the ID' do
        subject
        expect(aggregate_instance.location_id).to eq(location_id)
      end

      context 'when the guard evaluator raises an error' do
        before do
          allow(guard_evaluator_instance).to receive(:call).
            and_raise(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition, 'test error')
        end

        it 'does not update the read model' do
          original_id = aggregate_instance.location_id
          subject
          expect(aggregate_instance.location_id).to eq(original_id)
        end
      end
    end

    describe 'can_change methods' do
      let(:guard_evaluator_class) { Test::User::Commands::ChangeLocation::GuardEvaluator }
      let(:guard_evaluator_instance) { instance_double(guard_evaluator_class) }
      let(:location_id) { SecureRandom.uuid }
      let(:location) { instance_double('Test::Location::Aggregate', id: location_id) }

      let(:attribute_setup) do
        instance.call
      end

      before do
        attribute_setup

        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator_instance)
        allow(guard_evaluator_instance).to receive(:call).and_return(true)
        allow(guard_evaluator_instance).to receive(:accessed_external_aggregates).and_return([])
      end

      it 'checks if the aggregate can be changed' do
        expect(aggregate_instance.can_change_location?(location:)).to be_truthy
      end

      it 'checks if the aggregate ID can be changed' do
        expect(aggregate_instance.can_change_location_id?(location_id: location_id)).to be_truthy
      end

      context 'when the guard evaluator raises an error' do
        before do
          allow(guard_evaluator_instance).to receive(:call).
            and_raise(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition, 'test error')
        end

        it 'indicates the aggregate cannot be changed' do
          expect(aggregate_instance.can_change_location?(location:)).to be_falsey
        end

        it 'indicates the aggregate ID cannot be changed' do
          expect(aggregate_instance.can_change_location_id?(location_id: location_id)).to be_falsey
        end
      end
    end
  end
end
