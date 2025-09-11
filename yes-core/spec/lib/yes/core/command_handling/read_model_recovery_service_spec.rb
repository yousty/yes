# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::ReadModelRecoveryService do
  let(:read_model_class) do
    Class.new do
      def self.table_name
        'test_read_models'
      end
      
      def self.name
        'TestReadModel'
      end
      
      def self.column_names
        ['id', 'pending_update_since', 'revision']
      end
    end
  end
  
  let(:aggregate_class) do
    Class.new(Yes::Core::Aggregate) do
      def self.name
        'Test'
      end
      
      def latest_event
        Yousty::Eventsourcing::Event.new(
          id: SecureRandom.uuid,
          type: 'TestEvent',
          data: { foo: 'bar' },
          stream_revision: 5
        )
      end
      
    end
  end
  
  let(:read_model) do
    double(
      'read_model',
      id: SecureRandom.uuid,
      class: read_model_class,
      pending_update_since: 2.minutes.ago,
      pending_update_since?: true,
      reload: nil,
      update!: true
    )
  end
  
  let(:command_utilities) { double('command_utilities') }
  let(:revision_column) { :revision }
  let(:aggregate) { double('aggregate', read_model:, latest_event: nil) }
  
  describe '.recover_read_model' do
    subject(:recover) { described_class.recover_read_model(read_model, aggregate_class: aggregate_class, is_draft: false) }
    
    before do
      allow(described_class).to receive(:with_advisory_lock).and_yield
      allow(aggregate_class).to receive(:new).with(read_model.id).and_return(aggregate)
      allow(aggregate).to receive(:send).with(:command_utilities).and_return(command_utilities)
      allow(aggregate).to receive(:send).with(:revision_column).and_return(revision_column)
      allow(aggregate).to receive(:latest_event).and_return(
        Yousty::Eventsourcing::Event.new(
          id: SecureRandom.uuid,
          type: 'TestEvent',
          data: { foo: 'bar' },
          stream_revision: 5
        )
      )
      allow_any_instance_of(Yes::Core::CommandHandling::ReadModelUpdater).to receive(:call)
    end
    
    context 'when read model is stuck in pending state' do
      it 'recovers the read model successfully' do
        result = recover
        
        expect(result.success).to be true
        expect(result.read_model).to eq read_model
        expect(result.error_message).to be_nil
      end
      
      it 'fetches the latest event from the aggregate' do
        expect(aggregate).to receive(:latest_event)
        recover
      end
      
      it 'reapplies the state update' do
        expect_any_instance_of(Yes::Core::CommandHandling::ReadModelUpdater).to receive(:call)
        recover
      end
    end
    
    context 'when read model is already recovered' do
      before do
        allow(read_model).to receive(:pending_update_since?).and_return(false)
      end
      
      it 'returns success without attempting recovery' do
        result = recover
        
        expect(result.success).to be true
        expect(result.error_message).to eq 'Already recovered'
        expect(aggregate).not_to receive(:latest_event)
      end
    end
    
    context 'when recovery with aggregate class provided' do
      it 'instantiates the aggregate with the correct parameters' do
        expect(aggregate_class).to receive(:new).with(read_model.id).and_return(aggregate)
        recover
      end
      
      context 'when is_draft is true' do
        subject(:recover) { described_class.recover_read_model(read_model, aggregate_class: aggregate_class, is_draft: true) }
        
        it 'instantiates the aggregate with draft flag' do
          expect(aggregate_class).to receive(:new).with(read_model.id, draft: true).and_return(aggregate)
          recover
        end
      end
    end
    
    context 'when recovery fails' do
      before do
        allow_any_instance_of(Yes::Core::CommandHandling::ReadModelUpdater).to receive(:call)
          .and_raise(StandardError, 'Recovery failed')
      end
      
      it 'returns failure result with error message' do
        result = recover
        
        expect(result.success).to be false
        expect(result.error_message).to include 'Recovery failed'
      end
    end
  end
  
  describe '.recover_all_stuck_read_models' do
    subject(:recover_all) do
      described_class.recover_all_stuck_read_models(
        stuck_timeout: 1.minute,
        batch_size: 10
      )
    end
    
    let(:stuck_model_1) { double('stuck_model_1', id: '1', class: read_model_class, pending_update_since: 2.minutes.ago) }
    let(:stuck_model_2) { double('stuck_model_2', id: '2', class: read_model_class, pending_update_since: 3.minutes.ago) }
    
    before do
      allow(described_class).to receive(:find_stuck_read_models_with_aggregates).and_return([
        { read_model: stuck_model_1, aggregate_class: aggregate_class, is_draft: false },
        { read_model: stuck_model_2, aggregate_class: aggregate_class, is_draft: false }
      ])
      allow(described_class).to receive(:recover_read_model).and_return(
        described_class::RecoveryResult.new(success: true, read_model: nil)
      )
      allow(described_class).to receive(:log_recovery_result)
    end
    
    it 'finds all stuck read models with aggregates' do
      expect(described_class).to receive(:find_stuck_read_models_with_aggregates)
        .with(stuck_timeout: 1.minute, batch_size: 10)
      recover_all
    end
    
    it 'attempts to recover each stuck model with aggregate class' do
      expect(described_class).to receive(:recover_read_model)
        .with(stuck_model_1, aggregate_class: aggregate_class, is_draft: false)
      expect(described_class).to receive(:recover_read_model)
        .with(stuck_model_2, aggregate_class: aggregate_class, is_draft: false)
      recover_all
    end
    
    it 'returns array of recovery results' do
      results = recover_all
      expect(results).to be_an(Array)
      expect(results.size).to eq 2
      expect(results.all? { |r| r.is_a?(described_class::RecoveryResult) }).to be true
    end
    
    it 'logs each recovery result' do
      expect(described_class).to receive(:log_recovery_result).twice
      recover_all
    end
  end
end