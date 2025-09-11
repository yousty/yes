# frozen_string_literal: true

# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::CommandExecutor do
  # Test command class for specs
  class ExecutorTestCommand < Yes::Core::Command
    attribute :document_ids, ::Yousty::Eventsourcing::Types::UUID
    attribute? :another, ::Yousty::Eventsourcing::Types::String.optional
    attribute? :user_id, ::Yousty::Eventsourcing::Types::UUID.optional
  end

  subject(:executor) { described_class.new(aggregate) }

  let(:aggregate_id) { SecureRandom.uuid }
  let(:aggregate) { Test::User::Aggregate.new(aggregate_id) }
  let(:read_model) { TestUser.create!(id: aggregate_id, revision: -1) }
  let(:aggregate_class) { Test::User::Aggregate }
  
  let(:command) { ExecutorTestCommand.new(payload.merge(metadata: metadata, batch_id: nil)) }
  let(:payload) { { document_ids: SecureRandom.uuid } }
  let(:metadata) { {} }
  let(:guard_evaluator_class) { class_double(Yes::Core::CommandHandling::GuardEvaluator) }
  let(:guard_evaluator) { instance_double(Yes::Core::CommandHandling::GuardEvaluator) }
  let(:event_publisher) { instance_double(Yes::Core::CommandHandling::EventPublisher) }
  let(:event) { Yousty::Eventsourcing::Event.new(id: SecureRandom.uuid, type: 'TestEvent', data: {}) }
  let(:command_helper) { double('CommandHelper', command_name: 'ApproveDocuments') }

  before do
    allow(aggregate).to receive(:read_model).and_return(read_model)
    allow(Yousty::Eventsourcing::CommandHelper).to receive(:new).with(command).and_return(command_helper)
  end

  describe '#call' do
    context 'when guards are evaluated' do
      before do
        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator)
        allow(guard_evaluator).to receive(:call)
        allow(guard_evaluator).to receive(:accessed_external_aggregates).and_return([])
        allow(aggregate).to receive(:send)
        allow(read_model).to receive(:respond_to?).with(:pending_update_since=).and_return(true)
        allow(read_model).to receive(:update_column)
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_return(event_publisher)
        allow(event_publisher).to receive(:call).and_return(event)
      end

      it 'evaluates guards' do
        aggregate_failures do
          expect(guard_evaluator_class)
            .to receive(:new)
            .with(
              payload: payload,
              metadata: metadata,
              aggregate: aggregate,
              command_name: 'ApproveDocuments'
            )
            .and_return(guard_evaluator)
          
          expect(guard_evaluator).to receive(:call)
        end
        
        executor.call(command, guard_evaluator_class, skip_guards: false)
      end

      it 'clears command error on success' do
        expect(aggregate).to receive(:send).with(:approve_documents_error=, nil)
        
        executor.call(command, guard_evaluator_class, skip_guards: false)
      end

      context 'when guard evaluation fails' do
        let(:guard_error) { Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition.new('Invalid') }

        before do
          allow(guard_evaluator).to receive(:call).and_raise(guard_error)
        end

        it 'sets command error' do
          expect(aggregate).to receive(:send).with(:approve_documents_error=, 'Invalid')
          
          executor.call(command, guard_evaluator_class, skip_guards: false)
        end

        it 'returns error response' do
          result = executor.call(command, guard_evaluator_class, skip_guards: false)
          
          aggregate_failures do
            expect(result).to be_a(Yes::Core::CommandResponse)
            expect(result.cmd).to eq(command)
            expect(result.error).to eq(guard_error)
          end
        end
      end
    end

    context 'when guards are skipped' do
      before do
        allow(aggregate).to receive(:send)
        allow(read_model).to receive(:respond_to?).with(:pending_update_since=).and_return(true)
        allow(read_model).to receive(:update_column)
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_return(event_publisher)
        allow(event_publisher).to receive(:call).and_return(event)
      end

      it 'does not evaluate guards' do
        expect(guard_evaluator_class).not_to receive(:new)
        
        executor.call(command, guard_evaluator_class, skip_guards: true)
      end

      it 'clears command error' do
        expect(aggregate).to receive(:send).with(:approve_documents_error=, nil)
        
        executor.call(command, guard_evaluator_class, skip_guards: true)
      end
    end

    context 'pending state management' do
      before do
        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator)
        allow(guard_evaluator).to receive(:call)
        allow(guard_evaluator).to receive(:accessed_external_aggregates).and_return([])
        allow(aggregate).to receive(:send)
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_return(event_publisher)
        allow(event_publisher).to receive(:call).and_return(event)
        allow(read_model).to receive(:respond_to?).with(:pending_update_since=).and_return(true)
      end

      it 'sets pending state before publishing event' do
        expect(read_model).to receive(:update_column).with(:pending_update_since, kind_of(Time))
        
        executor.call(command, guard_evaluator_class, skip_guards: false)
      end

      context 'when event publication fails' do
        let(:error) { PgEventstore::Error.new('Event store error') }

        before do
          allow(event_publisher).to receive(:call).and_raise(error)
        end

        it 'clears pending state' do
          aggregate_failures do
            expect(read_model).to receive(:update_column).with(:pending_update_since, kind_of(Time)).ordered
            expect(read_model).to receive(:update_column).with(:pending_update_since, nil).ordered
            expect { executor.call(command, guard_evaluator_class, skip_guards: false) }.to raise_error(error)
          end
        end
      end

      context 'when setting pending state fails with trigger error' do
        before do
          allow(read_model)
            .to receive(:update_column)
            .with(:pending_update_since, kind_of(Time))
            .and_raise(ActiveRecord::StatementInvalid.new('Concurrent pending update not allowed for record 123'))
          allow(read_model)
            .to receive(:update_column)
            .with(:pending_update_since, nil)
        end

        it 'raises ConcurrentUpdateError for retry' do
          expect { executor.call(command, guard_evaluator_class, skip_guards: false) }
            .to raise_error(Yes::Core::CommandHandling::ConcurrentUpdateError)
        end
      end
    end

    context 'event publication' do
      before do
        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator)
        allow(guard_evaluator).to receive(:call)
        allow(guard_evaluator).to receive(:accessed_external_aggregates).and_return(['external_aggregate'])
        allow(aggregate).to receive(:send)
        allow(read_model).to receive(:respond_to?).with(:pending_update_since=).and_return(true)
        allow(read_model).to receive(:update_column)
      end

      it 'publishes event with correct data' do
        publication_data = instance_double(Yes::Core::CommandHandling::EventPublisher::AggregateEventPublicationData)
        
        aggregate_failures do
          expect(Yes::Core::CommandHandling::EventPublisher::AggregateEventPublicationData)
            .to receive(:from_aggregate)
            .with(aggregate)
            .and_return(publication_data)
          
          expect(Yes::Core::CommandHandling::EventPublisher)
            .to receive(:new)
            .with(
              command: command,
              aggregate_data: publication_data,
              accessed_external_aggregates: ['external_aggregate']
            )
            .and_return(event_publisher)
            
          expect(event_publisher).to receive(:call).and_return(event)
        end

        executor.call(command, guard_evaluator_class, skip_guards: false)
      end

      it 'returns success response with event' do
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_return(event_publisher)
        allow(event_publisher).to receive(:call).and_return(event)
        
        result = executor.call(command, guard_evaluator_class, skip_guards: false)
        
        aggregate_failures do
          expect(result).to be_a(Yes::Core::CommandResponse)
          expect(result.cmd).to eq(command)
          expect(result.event).to eq(event)
        end
      end
    end

    context 'revision conflict handling' do
      let(:revision_error) { PgEventstore::WrongExpectedRevisionError.new(revision: 1, expected_revision: 2, stream: {}) }

      before do
        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator)
        allow(guard_evaluator).to receive(:call)
        allow(guard_evaluator).to receive(:accessed_external_aggregates).and_return([])
        allow(aggregate).to receive(:send)
        allow(read_model).to receive(:respond_to?).with(:pending_update_since=).and_return(true)
        allow(read_model).to receive(:update_column)
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_return(event_publisher)
      end

      it 'retries on revision conflict up to MAX_RETRIES' do
        call_count = 0
        allow(event_publisher).to receive(:call) do
          call_count += 1
          if call_count < 3
            raise revision_error
          else
            event
          end
        end
        
        result = executor.call(command, guard_evaluator_class, skip_guards: false)
        
        aggregate_failures do
          expect(result).to be_a(Yes::Core::CommandResponse)
          expect(result.event).to eq(event)
          expect(call_count).to eq(3)
        end
      end

      it 'raises error after MAX_RETRIES' do
        allow(event_publisher).to receive(:call).and_raise(revision_error)
        
        expect { executor.call(command, guard_evaluator_class, skip_guards: false) }
          .to raise_error(revision_error)
      end

      context 'with concurrent update error' do
        let(:concurrent_error) do
          Yes::Core::CommandHandling::ConcurrentUpdateError.new(
            aggregate_class: aggregate.class,
            aggregate_id: 'test-id',
            original_error: ActiveRecord::RecordNotUnique.new('test')
          )
        end

        before do
          allow(event_publisher).to receive(:call).and_return(event)
        end

        it 'retries on concurrent update error' do
          call_count = 0
          allow(read_model).to receive(:update_column).with(:pending_update_since, kind_of(Time)) do
            call_count += 1
            if call_count < 3
              raise ActiveRecord::StatementInvalid.new('Concurrent pending update not allowed for record 123')
            end
          end
          allow(read_model).to receive(:update_column).with(:pending_update_since, nil)
          
          result = executor.call(command, guard_evaluator_class, skip_guards: false)
          
          aggregate_failures do
            expect(result).to be_a(Yes::Core::CommandResponse)
            expect(call_count).to eq(3)
          end
        end
      end

      it 'clears pending state on each retry' do
        call_count = 0
        allow(event_publisher).to receive(:call) do
          call_count += 1
          raise revision_error
        end
        
        # Track all update_column calls
        update_calls = []
        allow(read_model).to receive(:update_column) do |key, value|
          update_calls << [key, value]
        end
        
        aggregate_failures do
          expect { executor.call(command, guard_evaluator_class, skip_guards: false) }
            .to raise_error(revision_error)
          
          # Check that pending state was cleared (twice per retry: once in inner rescue, once in outer rescue)
          nil_updates = update_calls.select { |k, v| k == :pending_update_since && v.nil? }
          expect(nil_updates.count).to eq((described_class::MAX_RETRIES + 1) * 2)
        end
      end
    end

    context 'command group handling' do
      let(:command_group) do
        double('CommandGroup', 
               payload: payload, 
               metadata: metadata, 
               batch_id: 'batch123',
               is_a?: ->(klass) { klass == Yousty::Eventsourcing::CommandGroup })
      end
      
      before do
        allow(Yousty::Eventsourcing::CommandHelper).to receive(:new).with(command_group).and_return(command_helper)
        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator)
        allow(guard_evaluator).to receive(:call)
        allow(guard_evaluator).to receive(:accessed_external_aggregates).and_return([])
        allow(aggregate).to receive(:send)
        allow(read_model).to receive(:respond_to?).with(:pending_update_since=).and_return(true)
        allow(read_model).to receive(:update_column)
        allow(Yes::Core::CommandHandling::EventPublisher).to receive(:new).and_return(event_publisher)
        allow(event_publisher).to receive(:call).and_return(event)
      end

      it 'returns CommandGroupResponse for command groups' do
        result = executor.call(command_group, guard_evaluator_class, skip_guards: false)
        
        expect(result).to be_a(Yousty::Eventsourcing::Stateless::CommandGroupResponse)
      end
    end
  end
end