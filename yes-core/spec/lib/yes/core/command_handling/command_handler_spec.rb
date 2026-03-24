# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::CommandHandler do
  subject(:handler) { described_class.new(aggregate) }

  let(:aggregate_id) { SecureRandom.uuid }
  let(:user_id) { SecureRandom.uuid }
  let!(:read_model) { TestUser.create!(id: aggregate_id, name: 'John') }
  let(:aggregate) { Test::User::Aggregate.new(aggregate_id) }

  describe '#call' do
    subject { handler.call(command_name, payload, guards:) }

    let(:guards) { true }
    let(:command_name) { :change_name }
    let(:payload) { { name: 'Jane', user_id: } }

    context 'when command succeeds' do
      it 'updates the read model' do
        result = subject

        aggregate_failures do
          expect(result).to be_a(Yes::Core::Commands::Response)
          expect(result).to be_success
          expect(result.event).to be_present

          # Verify read model was updated
          read_model.reload
          expect(read_model.name).to eq('Jane')
          expect(read_model.revision).to eq(0)
        end
      end

      it 'publishes the event to the event store' do
        result = subject

        aggregate_failures do
          expect(result).to be_success
          expect(result.event).to be_present

          # Verify event properties
          expect(result.event).to be_a(Yes::Core::Event)
          expect(result.event.type).to eq('Test::UserNameChanged')
          expect(result.event.data).to include('name' => 'Jane', 'user_id' => user_id)
          expect(result.event.stream_revision).to eq(0)

          # Verify event metadata
          expect(result.event.metadata).to include('yes-dsl' => true)
          expect(result.event.metadata).to have_key('created_at')
        end
      end
    end

    context 'when guard fails' do
      let(:payload) { { name: 'John', user_id: } } # Same value - no_change guard will fail

      it 'returns error response without updating read model' do
        result = subject

        aggregate_failures do
          expect(result).to be_a(Yes::Core::Commands::Response)
          expect(result).not_to be_success
          expect(result.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition)

          # Verify read model was not updated
          read_model.reload
          expect(read_model.name).to eq('John')
          expect(read_model.revision).to eq(-1)
        end
      end
    end

    context 'when guards are disabled' do
      let(:guards) { false }
      let(:payload) { { name: 'John', user_id: } } # Same value that would normally fail

      it 'executes command even when guard would fail' do
        result = subject

        aggregate_failures do
          expect(result).to be_success
          expect(result.event).to be_present
        end
      end
    end

    context 'when read model needs recovery' do
      before do
        read_model.update_column(:pending_update_since, 1.minute.ago)

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
      end

      it 'recovers the read model and executes the command' do
        subject

        aggregate_failures do
          expect(read_model.reload.pending_update_since).to be_nil
          expect(read_model.name).to eq('Jane')
          expect(read_model.document_ids).to eq('doc-123')
          expect(read_model.another).to eq('test')
          expect(read_model.revision).to eq(1)
        end
      end
    end

    context 'with command that has custom event' do
      let(:command_name) { :approve_documents_with_custom_event }
      let(:payload) { { user_id: } }

      it 'uses the custom event type' do
        result = subject

        aggregate_failures do
          expect(result).to be_success
          expect(result.event.type).to include('DocumentHappilyApproved')
        end
      end
    end

    context 'when custom metadata is provided' do
      subject { handler.call(command_name, payload, guards:, metadata: custom_metadata) }

      let(:custom_metadata) { { propagated: true, source: 'parent_company' } }

      it 'merges custom metadata into event metadata' do
        result = subject

        aggregate_failures do
          expect(result).to be_success
          expect(result.event).to be_present

          # Verify custom metadata is present
          expect(result.event.metadata).to include('propagated' => true)
          expect(result.event.metadata).to include('source' => 'parent_company')

          # Verify standard metadata is still present
          expect(result.event.metadata).to include('yes-dsl' => true)
          expect(result.event.metadata).to have_key('created_at')
        end
      end

      context 'when metadata is nil' do
        let(:custom_metadata) { nil }

        it 'works without custom metadata' do
          result = subject

          aggregate_failures do
            expect(result).to be_success
            expect(result.event.metadata).to include('yes-dsl' => true)
            expect(result.event.metadata).not_to have_key('propagated')
          end
        end
      end
    end

    context 'when called from Rails console without origin' do
      let(:rails_app_class) { double(module_parent: double(name: 'CompanyManager')) }

      before do
        stub_const('Rails::Console', Class.new)
        allow(Rails).to receive(:application).and_return(double(class: rails_app_class))
        allow(Rails).to receive(:env).and_return('production')
      end

      it 'sets console origin on the event metadata' do
        result = subject

        aggregate_failures do
          expect(result).to be_success
          expect(result.event.metadata).to include('origin' => 'CompanyManager production console')
        end
      end
    end

    context 'when origin is already present in payload' do
      let(:payload) { { name: 'Jane', user_id:, origin: 'CommandBus > SomeController' } }

      before do
        stub_const('Rails::Console', Class.new)
        allow(Rails).to receive(:application).and_return(
          double(class: double(module_parent: double(name: 'CompanyManager')))
        )
        allow(Rails).to receive(:env).and_return('production')
      end

      it 'does not override existing origin' do
        result = subject

        aggregate_failures do
          expect(result).to be_success
          expect(result.event.metadata).to include('origin' => 'CommandBus > SomeController')
        end
      end
    end

    context 'when not in Rails console and no origin provided' do
      before do
        hide_const('Rails::Console')
      end

      it 'does not set origin in event metadata' do
        result = subject

        aggregate_failures do
          expect(result).to be_success
          expect(result.event.metadata).not_to have_key('origin')
        end
      end
    end

    context 'failure cases' do
      context 'when read model update fails' do
        before do
          updater_double = instance_double(Yes::Core::CommandHandling::ReadModelUpdater)
          allow(updater_double).to receive(:call).and_raise(StandardError, 'Some error')
          allow(Yes::Core::CommandHandling::ReadModelUpdater).to receive(:new).and_return(updater_double)
        end

        it 're-raises the error and leaves pending state set' do
          aggregate_failures do
            expect { subject }.to raise_error(StandardError, 'Some error')
            expect(read_model.reload.pending_update_since).not_to be_nil
          end
        end
      end

      context 'with concurrent updates' do
        before do
          # Simulate another process updating the record very recently
          read_model.update_column(:pending_update_since, 1.second.ago)
        end

        it 'raises ConcurrentUpdateError when another process owns the lock' do
          # When the pending state is too recent, it indicates another process is working
          expect { subject }.to raise_error(Yes::Core::CommandHandling::ConcurrentUpdateError)
        end
      end

      context 'when recovery service fails' do
        before do
          allow(Yes::Core::CommandHandling::ReadModelRecoveryService).
            to receive(:check_and_recover_with_retries).
            and_raise(StandardError, 'Recovery failed')
        end

        it 'propagates the error' do
          expect { handler.call(command_name, payload) }.to raise_error(StandardError, 'Recovery failed')
        end
      end

      context 'when command building fails' do
        let(:payload) { { name: 'Jane' } } # Missing required user_id

        it 'raises an error' do
          # The command utilities will add user_id from aggregate_id by default,
          # so let's test with a completely invalid payload
          invalid_payload = { invalid_field: 'value' }

          expect { handler.call(command_name, invalid_payload) }.to raise_error(Yes::Core::Command::Invalid)
        end
      end
    end
  end
end
