# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::GuardEvaluator do
  subject(:guard_evaluator) { guard_evaluator_class.new(payload:, aggregate:, command_name: :test_command) }

  let(:guard_evaluator_class) { described_class }
  let(:payload) { { location_id: } }
  let(:location_id) { SecureRandom.uuid }
  let(:location) { Test::Location::Aggregate.new(location_id) }
  let(:aggregate) { Test::User::Aggregate.new }

  before do
    Test::User::Aggregate.attribute :location_id, :uuid, command: true
    aggregate.change_location_id(location_id:)
  end

  after do
    # Clean up location attribute and guards
    Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                Test::User::Aggregate.attributes.except(:location_id))
    described_class.instance_variable_set(:@guards, [])
  end

  describe '.guard' do
    it 'registers a new guard' do
      described_class.guard(:test) { true }
      expect(described_class.guards.last[:name]).to eq(:test)
    end
  end

  describe '#call' do
    context 'when all guards pass' do
      before do
        described_class.guard(:test) { true }
      end

      it 'does not raise an error' do
        expect { guard_evaluator.call }.not_to raise_error
      end
    end

    context 'when a guard fails' do
      before do
        described_class.guard(:test) { false }
      end

      it 'raises an InvalidTransition error' do
        expect { guard_evaluator.call }.to raise_error(described_class::InvalidTransition)
      end
    end

    context 'when a no_change guard fails' do
      before do
        described_class.guard(:no_change) { false }
      end

      it 'raises a NoChangeTransition error' do
        expect { guard_evaluator.call }.to raise_error(described_class::NoChangeTransition)
      end
    end
  end

  describe 'guard evaluation context' do
    context 'when accessing payload methods' do
      context 'when accessing via payload hash' do
        before do
          described_class.guard(:test) { payload.location_id == location_id }
        end

        it 'has access to payload methods' do
          expect { guard_evaluator.call }.not_to raise_error
        end
      end

      context 'when accessing via payload aggregate attribute' do
        before do
          described_class.guard(:test) { payload.location.id == location_id }
        end

        it 'tracks the accessed aggregate' do
          guard_evaluator.call

          expect(guard_evaluator.accessed_external_aggregates).to include(
            hash_including(
              id: location_id,
              context: 'Test',
              name: 'Location',
              revision: kind_of(Proc)
            )
          )
        end
      end
    end

    context 'when accessing aggregate methods' do
      before do
        described_class.guard(:test) { name == 'John Doe' }
      end

      it 'delegates methods to the aggregate' do
        expect(aggregate).to receive(:name).and_return('John Doe')
        expect { guard_evaluator.call }.not_to raise_error
      end
    end
  end

  describe '#error_message' do
    let(:guard_name) { :test_guard }
    let(:guard_evaluator_class) do
      Class.new(described_class) do
        def self.name
          'Test::User::TestCommand::GuardEvaluator'
        end
      end
    end

    it 'generates the correct error message using ErrorMessages' do
      aggregate_failures do
        expect(Yes::Core::ErrorMessages).to receive(:guard_error).
          with('Test', 'User', 'TestCommand', guard_name).
          and_return('Error message')

        # Call the private method using send
        expect(guard_evaluator.send(:error_message, guard_name)).to eq('Error message')
      end
    end
  end
end
