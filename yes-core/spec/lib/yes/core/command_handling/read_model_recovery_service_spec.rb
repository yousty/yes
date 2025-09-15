# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::ReadModelRecoveryService do
  let(:aggregate_class) { Test::User::Aggregate }
  let(:read_model_class) { TestUser }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:aggregate) { aggregate_class.new(aggregate_id) }
  let(:read_model) { aggregate.read_model }
  let(:mock_updater) { instance_double(Yes::Core::CommandHandling::ReadModelUpdater) }
  let(:is_draft) { false }
  
  describe '.recover_read_model' do
    subject(:recover) { described_class.recover_read_model(read_model, aggregate_class:, is_draft:) }

    before do
      # Mock the ReadModelUpdater to isolate service logic
      allow(Yes::Core::CommandHandling::ReadModelUpdater).to receive(:new).and_return(mock_updater)
      allow(mock_updater).to receive(:call)
    end
    
    context 'when read model is stuck in pending state' do
      let(:created_aggregate) { aggregate_class.new(read_model.id) }

      before do
        # Simulate stuck state
        read_model.update_column(:pending_update_since, 2.minutes.ago)

        # Create an event to recover with
        stream = PgEventstore::Stream.new(
          context: 'Test',
          stream_name: 'User',
          stream_id: aggregate_id
        )
        PgEventstore.client.append_to_stream(
          stream,
          PgEventstore::Event.new(
            type: 'Test::UserDocumentsApproved',
            data: { user_id: aggregate_id, document_ids: 'doc-123', another: 'test' }
          )
        )

        allow(aggregate_class).to receive(:new).with(read_model.id).and_return(created_aggregate)
      end

      it 'recovers the read model successfully' do
        result = recover

        expect(result.success).to be true
        expect(result.read_model).to eq read_model
        expect(result.error_message).to be_nil
      end

      it 'fetches the latest event from the aggregate' do
        expect(created_aggregate).to receive(:latest_event).and_call_original

        recover
      end

      it 'reapplies the state update' do
        recover

        expect(mock_updater).to have_received(:call)
      end
    end
    
    context 'when read model is already recovered' do
      before do
        # Ensure pending_update_since is nil (already recovered)
        read_model.update_column(:pending_update_since, nil)
      end

      it 'returns success without attempting recovery' do
        result = recover

        aggregate_failures do
          expect(result.success).to be true
          expect(result.error_message).to eq 'Already recovered'
          # The aggregate should not be created if already recovered
          expect(aggregate_class).not_to receive(:new)
        end
      end
    end
    
    context 'when is_draft is true' do
      let(:is_draft) { true }

      before do
        read_model.update_column(:pending_update_since, 2.minutes.ago)
      end

      it 'instantiates the aggregate with draft flag' do
        expect(aggregate_class).to receive(:new).with(read_model.id, draft: true).and_call_original
        recover
      end
    end
    
    context 'when recovery fails' do
      before do
        # Set the read model to stuck state so recovery will be attempted
        read_model.update_column(:pending_update_since, 2.minutes.ago)

        # Create an event so there's something to recover
        stream = PgEventstore::Stream.new(
          context: 'Test',
          stream_name: 'User',
          stream_id: aggregate_id
        )
        PgEventstore.client.append_to_stream(
          stream,
          PgEventstore::Event.new(
            type: 'Test::UserDocumentsApproved',
            data: { user_id: aggregate_id, document_ids: 'doc-fail', another: 'fail-test' }
          )
        )

        # Make the recovery fail
        allow(mock_updater).to receive(:call)
          .and_raise(StandardError, 'Recovery failed')
      end

      it 'returns failure result with error message' do
        result = recover

        aggregate_failures do
          expect(result.success).to be false
          expect(result.error_message).to include 'Recovery failed'
        end
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

    let(:stuck_model_1) { aggregate_class.new(SecureRandom.uuid).read_model }
    let(:stuck_model_2) { aggregate_class.new(SecureRandom.uuid).read_model }

    before do
      # Clean up any existing stuck models from previous test runs
      read_model_class.where.not(pending_update_since: nil).update_all(pending_update_since: nil)
      
      # Set up our specific stuck models
      stuck_model_1.update_column(:pending_update_since, 2.minutes.ago)
      stuck_model_2.update_column(:pending_update_since, 3.minutes.ago)

      # Mock the configuration to return only our test aggregate mappings
      # This avoids trying to query non-existent tables
      allow(Yes::Core.configuration).to receive(:all_read_models_with_aggregate_classes).and_return([
        { read_model_class: read_model_class, aggregate_class: aggregate_class, is_draft: false }
      ])

      # Mock the actual recovery to isolate the orchestration logic
      # We're testing the orchestration, not the recovery itself (that's tested above)
      allow(described_class).to receive(:recover_read_model) do |read_model, **_options|
        # Return a result with the actual read_model so logging doesn't fail
        described_class::RecoveryResult.new(success: true, read_model:)
      end
    end
    
    it 'finds stuck read models using the configuration' do
      # The method should use the configuration to find stuck models
      expect(Yes::Core.configuration).to receive(:all_read_models_with_aggregate_classes).and_return([
        { read_model_class: read_model_class, aggregate_class: aggregate_class, is_draft: false }
      ])
      recover_all
    end
    
    it 'attempts to recover stuck models' do
      aggregate_failures do
        expect(described_class).to receive(:recover_read_model)
          .with(stuck_model_1, aggregate_class: aggregate_class, 
          is_draft: false)
        expect(described_class).to receive(:recover_read_model)
            .with(stuck_model_2, aggregate_class: aggregate_class, 
            is_draft: false)
      end

      recover_all
    end

    it 'returns array of recovery results' do
      results = recover_all
      aggregate_failures do
        expect(results).to be_an(Array)
        expect(results.size).to eq 2
        expect(results.all? { |r| r.is_a?(described_class::RecoveryResult) }).to be true
      end
    end 
  end
end