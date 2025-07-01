# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::GuardEvaluator do
  subject(:guard_evaluator) { guard_evaluator_class.new(payload:, metadata:, aggregate:, command_name: :test_command) }

  let(:guard_evaluator_class) { described_class }
  let(:payload) { { location_id: } }
  let(:metadata) { {} }
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
    described_class.instance_variable_set(:@guards, {})
  end

  describe '.guard' do
    it 'registers a new guard' do
      described_class.guard(:test) { true }
      expect(described_class.guards).to have_key(:test)
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

      context 'with locale in payload' do
        let(:payload) { { location_id:, locale: 'fr-CH' } }
        let(:locale_capturer) { Class.new { attr_accessor :value }.new }

        before do
          described_class.instance_variable_set(:@guards, {})

          # Allow method to capture the locale when called
          allow(aggregate).to receive(:capture_locale) { locale_capturer.value = I18n.locale.to_s }

          # Define a guard that calls the method we're using to capture the locale
          described_class.guard(:test) { capture_locale }

          # Run the guard evaluator
          guard_evaluator.call
        end

        it 'uses the locale from payload when evaluating guards' do
          # Verify the locale was correct during guard evaluation
          expect(locale_capturer.value).to eq('fr-CH')
        end
      end
    end

    context 'when accessing metadata' do
      let(:metadata) { { user_agent: 'TestAgent/1.0', request_id: 'req-123' } }

      context 'via hash-style access' do
        before do
          described_class.guard(:test) { payload.metadata[:user_agent] == 'TestAgent/1.0' }
        end

        it 'has access to metadata values' do
          expect { guard_evaluator.call }.not_to raise_error
        end
      end

      context 'via method-style access' do
        before do
          described_class.guard(:test) { payload.metadata.request_id == 'req-123' }
        end

        it 'has access to metadata values' do
          expect { guard_evaluator.call }.not_to raise_error
        end
      end

      context 'when metadata is nil' do
        let(:metadata) { nil }

        before do
          described_class.guard(:test) { payload.metadata[:some_key].nil? }
        end

        it 'handles nil metadata gracefully' do
          expect { guard_evaluator.call }.not_to raise_error
        end
      end
    end
  end

  describe '#value_changed?' do
    # Make value_changed? accessible for testing
    let(:evaluator_instance) { guard_evaluator }

    context 'with non-hash values' do
      it 'returns true when values are different' do
        expect(evaluator_instance.send(:value_changed?, 'old', 'new')).to be true
        expect(evaluator_instance.send(:value_changed?, 123, 456)).to be true
        expect(evaluator_instance.send(:value_changed?, true, false)).to be true
        expect(evaluator_instance.send(:value_changed?, nil, 'value')).to be true
      end

      it 'returns false when values are the same' do
        expect(evaluator_instance.send(:value_changed?, 'same', 'same')).to be false
        expect(evaluator_instance.send(:value_changed?, 123, 123)).to be false
        expect(evaluator_instance.send(:value_changed?, true, true)).to be false
        expect(evaluator_instance.send(:value_changed?, nil, nil)).to be false
      end
    end

    context 'with hash values' do
      it 'returns false when hashes are equal with string keys' do
        hash1 = { 'key' => 'value', 'nested' => { 'inner' => 'data' } }
        hash2 = { 'key' => 'value', 'nested' => { 'inner' => 'data' } }
        expect(evaluator_instance.send(:value_changed?, hash1, hash2)).to be false
      end

      it 'returns false when hashes are equal with symbol keys' do
        hash1 = { key: 'value', nested: { inner: 'data' } }
        hash2 = { key: 'value', nested: { inner: 'data' } }
        expect(evaluator_instance.send(:value_changed?, hash1, hash2)).to be false
      end

      it 'returns false when hashes are equal with mixed string/symbol keys' do
        hash1 = { 'key' => 'value', nested: { 'inner' => 'data' } }
        hash2 = { key: 'value', 'nested' => { inner: 'data' } }
        expect(evaluator_instance.send(:value_changed?, hash1, hash2)).to be false
      end

      it 'returns true when hash values differ' do
        hash1 = { key: 'value1' }
        hash2 = { key: 'value2' }
        expect(evaluator_instance.send(:value_changed?, hash1, hash2)).to be true
      end

      it 'returns true when hash keys differ' do
        hash1 = { key1: 'value' }
        hash2 = { key2: 'value' }
        expect(evaluator_instance.send(:value_changed?, hash1, hash2)).to be true
      end
    end

    context 'with mixed types' do
      it 'returns true when comparing hash with non-hash' do
        expect(evaluator_instance.send(:value_changed?, { key: 'value' }, 'string')).to be true
        expect(evaluator_instance.send(:value_changed?, 'string', { key: 'value' })).to be true
      end

      it 'handles one hash and one nil' do
        expect(evaluator_instance.send(:value_changed?, { key: 'value' }, nil)).to be true
        expect(evaluator_instance.send(:value_changed?, nil, { key: 'value' })).to be true
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
          with('Test', 'User', 'test_command', guard_name).
          and_return('Error message')

        # Call the private method using send
        expect(guard_evaluator.send(:error_message, guard_name)).to eq('Error message')
      end
    end
  end
end
