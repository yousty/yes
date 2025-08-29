# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::HasReadModel do
  let(:aggregate_class) do
    Class.new(Yes::Core::Aggregate) do
      include Yes::Core::Aggregate::HasReadModel

      def self.name
        'TestContext::TestAggregate::Aggregate'
      end

      def self.context
        'TestContext'
      end

      def self.aggregate
        'TestAggregate'
      end
    end
  end

  let(:instance) { aggregate_class.new(aggregate_id) }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:read_model) { instance_double('ReadModel') }

  before do
    allow(instance).to receive(:read_model).and_return(read_model)
  end

  describe '#revision' do
    subject(:revision) { instance.revision }

    context 'when revision column exists' do
      before do
        allow(instance).to receive(:revision_column).and_return(:test_context_test_aggregate_revision)
        allow(read_model).to receive(:test_context_test_aggregate_revision).and_return(10)
      end

      it 'returns the revision from the read model' do
        expect(revision).to eq(10)
      end
    end

    context 'when using default revision column' do
      before do
        allow(instance).to receive(:revision_column).and_return(:revision)
        allow(read_model).to receive(:revision).and_return(5)
      end

      it 'returns the revision from the read model' do
        expect(revision).to eq(5)
      end
    end
  end

  describe '#init_revision_from_stream' do
    subject(:init_revision_from_stream) { instance.init_revision_from_stream }

    let(:event_revision) { 42 }

    before do
      allow(instance).to receive(:event_revision).and_return(event_revision)
      allow(instance).to receive(:revision_column).and_return(:test_revision)
    end

    it 'updates the revision column with the event revision' do
      expect(read_model).to receive(:update_column).with(:test_revision, 42).and_return(true)
      expect(init_revision_from_stream).to be true
    end

    it 'bypasses validations by using update_column' do
      expect(read_model).to receive(:update_column).with(:test_revision, 42)
      expect(read_model).not_to receive(:update!)
      expect(read_model).not_to receive(:save!)
      
      init_revision_from_stream
    end

    context 'when event_revision raises an error' do
      before do
        allow(instance).to receive(:event_revision).and_raise(NoMethodError, 'undefined method')
      end

      it 'propagates the error' do
        expect { init_revision_from_stream }.to raise_error(NoMethodError, 'undefined method')
      end
    end

    context 'with custom revision column' do
      before do
        allow(instance).to receive(:revision_column).and_return(:custom_revision)
      end

      it 'updates the custom revision column' do
        expect(read_model).to receive(:update_column).with(:custom_revision, 42).and_return(true)
        expect(init_revision_from_stream).to be true
      end
    end
  end
end