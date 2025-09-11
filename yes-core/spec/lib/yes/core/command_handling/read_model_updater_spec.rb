# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::ReadModelUpdater do
  subject(:updater) { described_class.new(aggregate) }

  let(:aggregate) { instance_double(Yes::Core::Aggregate) }
  let(:read_model) { instance_double(ActiveRecord::Base, id: aggregate_id) }
  let(:aggregate_id) { SecureRandom.uuid }
  let(:aggregate_class) { class_double(Yes::Core::Aggregate) }
  let(:command_utilities) { instance_double(Yes::Core::Utils::CommandUtils) }
  let(:revision_column) { :revision }
  
  let(:event) { instance_double(Yousty::Eventsourcing::Event, stream_revision: 5, data: event_data) }
  let(:event_data) { { document_ids: SecureRandom.uuid } }
  let(:command_payload) { { document_ids: SecureRandom.uuid, another: 'value', locale: 'en' } }
  let(:command_name) { :approve_documents }
  let(:state_updater_class) { class_double(Yes::Core::CommandHandling::StateUpdater) }
  let(:state_updater) { instance_double(Yes::Core::CommandHandling::StateUpdater) }
  let(:state_changes) { { document_ids: command_payload[:document_ids], another: command_payload[:another] } }

  before do
    allow(aggregate).to receive(:read_model).and_return(read_model)
    allow(aggregate).to receive(:send).with(:command_utilities).and_return(command_utilities)
    allow(aggregate).to receive(:send).with(:revision_column).and_return(revision_column)
    allow(aggregate).to receive(:class).and_return(aggregate_class)
  end

  describe '#call' do
    before do
      allow(command_utilities).to receive(:fetch_state_updater_class).and_return(state_updater_class)
      allow(state_updater_class).to receive(:new).and_return(state_updater)
      allow(state_updater).to receive(:call).and_return(state_changes)
      allow(aggregate).to receive(:update_read_model).with(anything)
    end

    context 'with revision guard' do
      it 'calls ReadModelRevisionGuard with correct parameters' do
        expect(Yes::Core::CommandHandling::ReadModelRevisionGuard)
          .to receive(:call)
          .with(read_model, 5, revision_column: :revision)
          .and_yield
        
        updater.call(event, command_payload, command_name)
      end

      context 'when using custom revision column' do
        let(:revision_column) { :test_user_revision }

        it 'passes custom revision column to guard' do
          expect(Yes::Core::CommandHandling::ReadModelRevisionGuard)
            .to receive(:call)
            .with(read_model, 5, revision_column: :test_user_revision)
            .and_yield
          
          updater.call(event, command_payload, command_name)
        end
      end
    end

    context 'state updater execution' do
      before do
        allow(Yes::Core::CommandHandling::ReadModelRevisionGuard).to receive(:call).and_yield
      end

      it 'fetches the state updater class' do
        expect(command_utilities)
          .to receive(:fetch_state_updater_class)
          .with(command_name)
          .and_return(state_updater_class)
        
        updater.call(event, command_payload, command_name)
      end

      it 'instantiates state updater with filtered payload' do
        filtered_payload = command_payload.except(:locale, *Yousty::Eventsourcing::Command::RESERVED_KEYS)
        
        expect(state_updater_class)
          .to receive(:new)
          .with(
            payload: filtered_payload,
            aggregate: aggregate,
            event: event
          )
          .and_return(state_updater)
        
        updater.call(event, command_payload, command_name)
      end

      it 'executes state updater' do
        expect(state_updater).to receive(:call).and_return(state_changes)
        
        updater.call(event, command_payload, command_name)
      end
    end

    context 'read model update' do
      before do
        allow(Yes::Core::CommandHandling::ReadModelRevisionGuard).to receive(:call).and_yield
      end

      it 'updates read model with state changes and metadata' do
        expected_attributes = state_changes.merge(
          revision: 5,
          locale: 'en',
          pending_update_since: nil
        )
        
        expect(aggregate)
          .to receive(:update_read_model)
          .with(expected_attributes)
        
        updater.call(event, command_payload, command_name)
      end

      it 'removes locale from command payload' do
        payload_after = command_payload.dup
        
        updater.call(event, payload_after, command_name)
        
        expect(payload_after).not_to have_key(:locale)
      end

      context 'when locale is not present' do
        let(:command_payload) { { document_ids: SecureRandom.uuid, another: 'value' } }

        it 'includes locale as nil in update attributes' do
          expected_attributes = state_changes.merge(
            revision: 5,
            locale: nil,
            pending_update_since: nil
          )
          
          expect(aggregate)
            .to receive(:update_read_model)
            .with(expected_attributes)
          
          updater.call(event, command_payload, command_name)
        end
      end
    end

    context 'when command name is not provided' do
      before do
        allow(Yes::Core::CommandHandling::ReadModelRevisionGuard).to receive(:call).and_yield
        allow(command_utilities).to receive(:command_name_from_event).and_return(:approve_documents)
      end

      it 'derives command name from event' do
        aggregate_failures do
          expect(command_utilities)
            .to receive(:command_name_from_event)
            .with(event, aggregate_class)
            .and_return(:approve_documents)
          
          expect(command_utilities)
            .to receive(:fetch_state_updater_class)
            .with(:approve_documents)
            .and_return(state_updater_class)
        end
        
        updater.call(event, command_payload)
      end
    end

    context 'error handling' do
      context 'when revision guard fails' do
        let(:error) { Yes::Core::CommandHandling::ReadModelRevisionGuard::RevisionMismatchError.new('Mismatch') }

        before do
          allow(Yes::Core::CommandHandling::ReadModelRevisionGuard)
            .to receive(:call)
            .and_raise(error)
        end

        it 'propagates the error' do
          expect { updater.call(event, command_payload, command_name) }.to raise_error(error)
        end
      end

      context 'when state updater fails' do
        let(:error) { StandardError.new('State update failed') }

        before do
          allow(Yes::Core::CommandHandling::ReadModelRevisionGuard).to receive(:call).and_yield
          allow(state_updater).to receive(:call).and_raise(error)
        end

        it 'propagates the error' do
          expect { updater.call(event, command_payload, command_name) }.to raise_error(error)
        end
      end

      context 'when read model update fails' do
        let(:error) { ActiveRecord::StaleObjectError.new('Stale object') }

        before do
          allow(Yes::Core::CommandHandling::ReadModelRevisionGuard).to receive(:call).and_yield
          allow(aggregate).to receive(:update_read_model).with(anything).and_raise(error)
        end

        it 'propagates the error' do
          expect { updater.call(event, command_payload, command_name) }.to raise_error(error)
        end
      end
    end
  end
end