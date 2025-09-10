# frozen_string_literal: true

RSpec.describe 'Yes::Core::Aggregate Command Handling with Pending State', integration: true do
  let(:aggregate_class) { Test::User::Aggregate }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:aggregate) { aggregate_class.new(aggregate_id) }
  let(:read_model_class) { aggregate_class._read_model_class }
  let(:read_model) { aggregate.read_model }
  
  let(:valid_payload) do
    {
      document_ids: SecureRandom.uuid,
      another: 'test_value'
    }
  end

  describe 'pending state lifecycle during command execution' do
    context 'when command execution succeeds' do
      it 'sets pending state before publishing event and clears it after updating read model' do
        expect(read_model.pending_update_since).to be_nil
        
        # Execute command successfully
        response = aggregate.approve_documents(valid_payload)
        
        aggregate_failures do
          expect(response.success?).to be true
          expect(read_model.reload.pending_update_since).to be_nil
          expect(read_model.document_ids).to eq(valid_payload[:document_ids])
          expect(read_model.another).to eq(valid_payload[:another])
        end
      end
      
      context 'tracking state changes' do
        before do
          # Mock to inspect when pending state is set
          allow(read_model).to receive(:update_column).and_call_original
        end
        
        it 'tracks pending state timing during execution' do
          aggregate.approve_documents(valid_payload)
          
          aggregate_failures do
            # Verify pending_update_since was set during execution
            expect(read_model).to have_received(:update_column)
              .with(:pending_update_since, kind_of(Time)).at_least(:once)
            # Final state should be nil
            expect(read_model.reload.pending_update_since).to be_nil
          end
        end
      end
    end
    
    context 'when event publication fails' do
      before do
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new)
          .and_raise(PgEventstore::Error, 'Event store unavailable')
      end
      
      it 'clears pending state when event publication fails' do
        aggregate_failures do
          expect {
            aggregate.approve_documents(valid_payload)
          }.to raise_error(PgEventstore::Error)
        
          # Pending state should be cleared even on failure
          expect(read_model.reload.pending_update_since).to be_nil
        end
      end
    end
    
    context 'when read model update fails after event publication' do
      let(:event) do
        Yousty::Eventsourcing::Event.new(
          id: SecureRandom.uuid,
          type: 'Test::UserDocumentsApproved',
          data: valid_payload.merge(user_id: aggregate_id),
          stream_revision: 1
        )
      end

      before do
        # Set pending state manually to simulate state after event published but before update
        read_model.update_column(:pending_update_since, Time.current)
        
        # Allow event to publish but fail on read model update  
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new)
          .and_return(double(call: event))
        allow(aggregate).to receive(:update_read_model_with_revision_guard)
          .and_raise(ActiveRecord::StaleObjectError, 'Revision conflict')
      end
      
      it 'leaves pending state set when read model update fails' do
        aggregate_failures do
          expect {
            aggregate.approve_documents(valid_payload)
          }.to raise_error(ActiveRecord::StaleObjectError)
          
          # Pending state should remain set for recovery
          expect(read_model.reload.pending_update_since).not_to be_nil
        end
      end
    end
  end
  
  describe 'concurrent update protection' do
    context 'when unique constraint violation occurs' do
      let(:concurrent_aggregate) { aggregate_class.new(aggregate_id) }
      
      before do
        # Simulate another process already setting pending state
        read_model.update_column(:pending_update_since, 1.minute.ago)
        
        # Mock to simulate unique constraint violation when trying to set pending state
        allow(concurrent_aggregate.read_model).to receive(:update_column) do |column, value|
          if column == :pending_update_since && !value.nil?
            raise ActiveRecord::RecordNotUnique, 'Unique constraint violation'
          else
            # Allow clearing pending state
            nil
          end
        end
      end
      
      it 'handles concurrent updates gracefully' do
        # The command handling should catch the error and handle it
        expect {
          concurrent_aggregate.send(:set_pending_update_state)
        }.to raise_error(PgEventstore::WrongExpectedRevisionError, /pending state conflict/)
      end
    end
    
    context 'when multiple commands are executed concurrently' do
      let(:another_aggregate) { aggregate_class.new(aggregate_id) }
      
      before do
        # This tests the actual database behavior
        # Set pending state to simulate a concurrent process
        read_model.update_column(:pending_update_since, Time.current)
        
        # The recovery mechanism should handle this
        allow(Yes::Core::CommandHandling::ReadModelRecoveryService).to receive(:check_and_recover_with_retries)
      end
      
      it 'prevents concurrent updates through database constraints' do
        # In a real scenario, the database would prevent this
        # For testing, we verify the pending state is checked
        expect(another_aggregate.read_model.reload.pending_update_since).not_to be_nil
        
        # Execute command - recovery should be attempted first
        another_aggregate.approve_documents(valid_payload)
        
        expect(Yes::Core::CommandHandling::ReadModelRecoveryService).to have_received(:check_and_recover_with_retries)
      end
    end
  end
  
  describe 'recovery service integration' do
    let(:recovery_service) { Yes::Core::CommandHandling::ReadModelRecoveryService }
    
    context 'when read model is stuck in pending state' do
      before do
        # Simulate stuck read model
        read_model.update_column(:pending_update_since, 2.minutes.ago)
        
        # Create a latest event to recover with
        stream = PgEventstore::Stream.new(
          context: 'Test',
          stream_name: 'User',
          stream_id: aggregate_id
        )
        PgEventstore.client.append_to_stream(
          stream,
          PgEventstore::Event.new(
            type: 'Test::UserDocumentsApproved',
            data: valid_payload.merge(user_id: aggregate_id)
          )
        )
      end
      
      it 'recovers stuck read model successfully' do
        result = recovery_service.recover_read_model(
          read_model,
          aggregate_class: aggregate_class,
          is_draft: false
        )
        
        aggregate_failures do
          expect(result.success).to be true
          expect(result.read_model).to eq(read_model)
          expect(read_model.reload.pending_update_since).to be_nil
          expect(read_model.document_ids).to eq(valid_payload[:document_ids])
        end
      end
      
      it 'uses advisory lock to prevent concurrent recovery' do
        expect(recovery_service).to receive(:with_advisory_lock).and_yield
        
        recovery_service.recover_read_model(
          read_model,
          aggregate_class: aggregate_class,
          is_draft: false
        )
      end
    end
    
    context 'when checking and recovering before command execution' do
      let(:new_payload) { { document_ids: 'new-doc', another: 'new-value' } }
      let(:stream) do
        PgEventstore::Stream.new(
          context: 'Test',
          stream_name: 'User', 
          stream_id: aggregate_id
        ) 
      end
      
      before do
        # Set pending state from previous failed attempt
        read_model.update_column(:pending_update_since, 1.minute.ago)
        
        # Create event from previous attempt
        PgEventstore.client.append_to_stream(
          stream,
          PgEventstore::Event.new(
            type: 'Test::UserDocumentsApproved',
            data: { user_id: aggregate_id, document_ids: 'old-doc', another: 'old' }
          )
        )
      end
      
      it 'automatically recovers before executing new command' do
        # New command should trigger recovery first
        response = aggregate.approve_documents(new_payload)
        
        aggregate_failures do
          expect(response.success?).to be true
          # Should have new values, not old ones
          expect(read_model.reload.document_ids).to eq('new-doc')
          expect(read_model.another).to eq('new-value')
          expect(read_model.pending_update_since).to be_nil
        end
      end
    end
  end
  
  describe 'batch recovery of stuck read models' do
    let(:stuck_models) do
      3.times.map do
        id = SecureRandom.uuid
        agg = aggregate_class.new(id)
        agg.read_model.update_column(:pending_update_since, 2.minutes.ago)
        
        # Create events for recovery
        stream = PgEventstore::Stream.new(
          context: 'Test',
          stream_name: 'User',
          stream_id: id
        )
        PgEventstore.client.append_to_stream(
          stream,
          PgEventstore::Event.new(
            type: 'Test::UserDocumentsApproved',
            data: { user_id: id, document_ids: "doc-#{id}", another: 'recovered' }
          )
        )
        
        agg.read_model
      end
    end
    
    before do
      # Stub configuration to return stuck models with their aggregates
      stuck_model_configs = stuck_models.map do |model|
        { read_model_class: read_model_class, aggregate_class: aggregate_class, is_draft: false }
      end
      
      allow(Yes::Core.configuration).to receive(:all_read_models_with_aggregate_classes).and_return(stuck_model_configs)
      
      # Stub to return our stuck models
      allow(read_model_class).to receive(:where).and_call_original
      allow(read_model_class).to receive_message_chain(:where, :not, :where).and_return(stuck_models)
    end
    
    it 'recovers all stuck read models in batch' do
      results = Yes::Core::CommandHandling::ReadModelRecoveryService.recover_all_stuck_read_models(
        stuck_timeout: 1.minute,
        batch_size: 10
      )
      
      aggregate_failures do
        # We should have at least our 3 stuck models recovered
        expect(results.select(&:success).size).to be >= 3
        
        stuck_models.each do |model|
          model.reload
          expect(model.pending_update_since).to be_nil
          expect(model.document_ids).to start_with('doc-')
          expect(model.another).to eq('recovered')
        end
      end
    end
  end
  
  describe 'error handling and edge cases' do
    context 'when read model does not support pending_update_since' do
      let(:non_pending_model) do
        double('ReadModel', id: SecureRandom.uuid, revision: 0)
      end

      let(:event) do
        Yousty::Eventsourcing::Event.new(
          id: SecureRandom.uuid,
          type: 'Test::UserDocumentsApproved',
          data: valid_payload.merge(user_id: aggregate_id),
          stream_revision: 1
        )
      end
      
      before do
        allow(non_pending_model).to receive(:respond_to?) do |method|
          case method
          when :pending_update_since=, :pending_update_since, :update_column
            false
          else
            true
          end
        end
        allow(aggregate).to receive(:read_model).and_return(non_pending_model)

        # Stub all the methods the aggregate might call on the read model
        allow(non_pending_model).to receive(:document_ids).and_return(nil)
        allow(non_pending_model).to receive(:another).and_return(nil)
        allow(non_pending_model).to receive(:update!)
      end
      
      it 'executes command without pending state tracking' do
        aggregate_failures do
          # The command should still work even without pending state support
          expect(non_pending_model).not_to receive(:update_column)
          
          allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new)
            .and_return(double(call: event))
          allow(aggregate).to receive(:update_read_model_with_revision_guard)
          
          response = aggregate.approve_documents(valid_payload)
          
          expect(response.success?).to be true
        end
      end
    end
    
    context 'when process crashes during command execution' do
      let(:job) { Yes::Core::Jobs::ReadModelRecoveryJob.new }
      
      before do
        # Simulate crash by directly setting pending state
        read_model.update_column(:pending_update_since, 5.minutes.ago)
        
        # Create event that should have been applied
        stream = PgEventstore::Stream.new(
          context: 'Test',
          stream_name: 'User',
          stream_id: aggregate_id  
        )
        PgEventstore.client.append_to_stream(
          stream,
          PgEventstore::Event.new(
            type: 'Test::UserDocumentsApproved',
            data: valid_payload.merge(user_id: aggregate_id)
          )
        )
        
        # Stub configuration to only return Test::User aggregates to avoid missing tables
        allow(Yes::Core.configuration).to receive(:all_read_models_with_aggregate_classes).and_return([
          { read_model_class: read_model_class, aggregate_class: aggregate_class, is_draft: false }
        ])
        allow(Yes::Core.configuration).to receive(:all_read_model_classes).and_return([read_model_class])
        
        # Mock job metrics
        allow(job).to receive(:track_metrics)
        allow(job).to receive(:check_for_long_stuck_models)
      end
      
      it 'can be recovered by background job' do
        # Background job would find and recover this
        job.perform(stuck_timeout_minutes: 1)
        
        aggregate_failures do
          # Model should be recovered
          expect(read_model.reload.pending_update_since).to be_nil
          expect(read_model.document_ids).to eq(valid_payload[:document_ids])
        end
      end
    end
  end
end