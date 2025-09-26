# frozen_string_literal: true

RSpec.describe 'Yes::Core::Aggregate Command Handling with Pending State', integration: true do
  let(:aggregate_class) { Test::User::Aggregate }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:aggregate) { aggregate_class.new(aggregate_id) }
  let(:read_model_class) { aggregate_class.read_model_class }
  let(:read_model) { aggregate.read_model }
  
  let(:valid_payload) do
    {
      document_ids: SecureRandom.uuid,
      another: 'test_value'
    }
  end

  subject { aggregate.approve_documents(valid_payload) }

  describe 'pending state lifecycle during command execution' do
    context 'when command execution succeeds' do
      it 'sets pending state before publishing event and clears it after updating read model' do
        # Capture the pending state at the moment of event publishing
        pending_state_during_publish = nil
        
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_wrap_original do |original, **kwargs|
          publisher = original.call(**kwargs)
          
          # Capture state just before publishing
          allow(publisher).to receive(:call).and_wrap_original do |method|
            # At this point, pending_update_since should be set
            pending_state_during_publish = read_model.reload.pending_update_since
            method.call
          end
          
          publisher
        end

        expect(read_model.pending_update_since).to be_nil
        
        # Execute command successfully
        response = subject
        
        aggregate_failures do
          expect(response.success?).to be true
          # Verify pending state was set during event publishing
          expect(pending_state_during_publish).not_to be_nil
          expect(pending_state_during_publish).to be_a(Time)
          # Verify pending state is cleared after read model update
          expect(read_model.reload.pending_update_since).to be_nil
          expect(read_model.document_ids).to eq(valid_payload[:document_ids])
          expect(read_model.another).to eq(valid_payload[:another])
        end
      end
    end
    
    context 'when event publication fails' do
      before do
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new)
          .and_raise(PgEventstore::Error, 'Event store unavailable')
      end
      
      it 'clears pending state when event publication fails' do
        # will clear pending stet on error, then reraise the error
        subject rescue nil
      
        # Pending state should be cleared even on failure
        expect(read_model.reload.pending_update_since).to be_nil
      end
    end
    
    context 'when read model update fails after event publication' do
      before do
        updater_double = instance_double(Yes::Core::CommandHandling::ReadModelUpdater)
        allow(updater_double).to receive(:call).and_raise('Some error')
        allow(Yes::Core::CommandHandling::ReadModelUpdater).to receive(:new).and_return(updater_double)
      end
      
      it 'leaves pending state set when read model update fails' do
        subject rescue nil
        
        # Pending state should remain set for recovery
        expect(read_model.reload.pending_update_since).not_to be_nil
      end
    end
  end
  
  describe 'concurrent update protection', use_transactional_fixtures: false do
    context 'when pending update is already set' do
      let(:concurrent_aggregate) { aggregate_class.new(aggregate_id) }
      
      before do
        # Simulate another process already setting pending state (but recent, < 5 seconds)
        read_model.update_column(:pending_update_since, 2.seconds.ago)
      end
      
      it 'handles concurrent updates gracefully' do
        # Since we retry up to 5 times, and the pending state is still set,
        # it should eventually fail with ConcurrentUpdateError after exhausting retries
        expect {
          concurrent_aggregate.approve_documents(valid_payload)
        }.to raise_error(Yes::Core::CommandHandling::ConcurrentUpdateError, /Concurrent update detected/)
      end
    end
  end
  
  describe 'recovery service integration' do
    context 'when checking and recovering before command execution' do
      let(:valid_payload) { { document_ids: 'new-doc', another: 'new-value' } }
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
        response = subject
        
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
end