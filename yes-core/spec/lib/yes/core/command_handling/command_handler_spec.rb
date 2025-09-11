# frozen_string_literal: true

# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::CommandHandler do
  # Test command class for specs
  class HandlerTestCommand < Yes::Core::Command
    attribute :document_ids, ::Yousty::Eventsourcing::Types::UUID
    attribute? :another, ::Yousty::Eventsourcing::Types::String.optional
    attribute? :user_id, ::Yousty::Eventsourcing::Types::UUID.optional
  end

  subject(:handler) { described_class.new(aggregate) }

  let(:aggregate_id) { SecureRandom.uuid }
  let(:aggregate) { Test::User::Aggregate.new(aggregate_id) }
  let(:read_model) { TestUser.create!(id: aggregate_id, revision: -1) }
  let(:command_utilities) { aggregate.send(:command_utilities) }
  
  let(:command_name) { :approve_documents }
  let(:payload) { { document_ids: SecureRandom.uuid, another: 'value' } }
  let(:prepared_payload) { payload.merge(user_id: aggregate_id) }
  let(:command) { HandlerTestCommand.new(prepared_payload.merge(metadata: {})) }
  let(:guard_evaluator_class) { class_double(Yes::Core::CommandHandling::GuardEvaluator) }
  let(:executor) { instance_double(Yes::Core::CommandHandling::CommandExecutor) }
  let(:response) { double('CommandResponse') }
  let(:event) { Yousty::Eventsourcing::Event.new(id: SecureRandom.uuid, type: 'TestEvent', data: {}) }

  before do
    allow(aggregate).to receive(:read_model).and_return(read_model)
  end

  describe '#call' do
    before do
      allow(Yes::Core::CommandHandling::ReadModelRecoveryService).to receive(:check_and_recover_with_retries)
      allow(command_utilities).to receive(:prepare_command_payload).and_return(prepared_payload)
      allow(command_utilities).to receive(:prepare_assign_command_payload).and_return(prepared_payload)
      allow(command_utilities).to receive(:build_command).and_return(command)
      allow(command_utilities).to receive(:fetch_guard_evaluator_class).and_return(guard_evaluator_class)
      allow(Yes::Core::CommandHandling::CommandExecutor).to receive(:new).and_return(executor)
      allow(executor).to receive(:call).and_return(response)
      allow(response).to receive(:success?).and_return(true)
      allow(response).to receive(:event).and_return(event)
      allow_any_instance_of(Yes::Core::CommandHandling::ReadModelUpdater).to receive(:call)
    end

    it 'checks and recovers pending state before execution' do
      expect(Yes::Core::CommandHandling::ReadModelRecoveryService)
        .to receive(:check_and_recover_with_retries)
        .with(read_model, aggregate: aggregate)
      
      handler.call(command_name, payload)
    end

    it 'prepares the command payload' do
      aggregate_failures do
        expect(command_utilities)
          .to receive(:prepare_command_payload)
          .with(command_name, anything, aggregate.class)
          .and_return(prepared_payload)
        
        expect(command_utilities)
          .to receive(:prepare_assign_command_payload)
          .with(command_name, prepared_payload)
          .and_return(prepared_payload)
      end
      
      handler.call(command_name, payload)
    end

    context 'when aggregate is a draft' do
      before do
        allow(aggregate).to receive(:draft?).and_return(true)
      end

      it 'adds draft metadata to payload' do
        expect(command_utilities)
          .to receive(:build_command)
          .with(command_name, hash_including(metadata: { draft: true }))
          .and_return(command)
        
        handler.call(command_name, payload)
      end
    end

    it 'builds and executes the command' do
      aggregate_failures do
        expect(command_utilities)
          .to receive(:build_command)
          .with(command_name, prepared_payload)
          .and_return(command)
        
        expect(command_utilities)
          .to receive(:fetch_guard_evaluator_class)
          .with(command_name)
          .and_return(guard_evaluator_class)
        
        expect(Yes::Core::CommandHandling::CommandExecutor)
          .to receive(:new)
          .with(aggregate)
          .and_return(executor)
        
        expect(executor)
          .to receive(:call)
          .with(command, guard_evaluator_class, skip_guards: false)
          .and_return(response)
      end
      
      handler.call(command_name, payload)
    end

    context 'when guards are disabled' do
      it 'passes skip_guards flag to executor' do
        expect(executor)
          .to receive(:call)
          .with(command, guard_evaluator_class, skip_guards: true)
          .and_return(response)
        
        handler.call(command_name, payload, guards: false)
      end
    end

    context 'when command execution succeeds' do
      before do
        allow(response).to receive(:success?).and_return(true)
      end

      it 'updates the read model' do
        expect_any_instance_of(Yes::Core::CommandHandling::ReadModelUpdater)
          .to receive(:call)
          .with(event, prepared_payload, command_name)
        
        handler.call(command_name, payload)
      end

      it 'returns the response' do
        result = handler.call(command_name, payload)
        expect(result).to eq(response)
      end
    end

    context 'when command execution fails' do
      before do
        allow(response).to receive(:success?).and_return(false)
      end

      it 'does not update the read model' do
        expect_any_instance_of(Yes::Core::CommandHandling::ReadModelUpdater).not_to receive(:call)
        
        handler.call(command_name, payload)
      end

      it 'returns the error response' do
        result = handler.call(command_name, payload)
        expect(result).to eq(response)
      end
    end

    context 'when read model update fails' do
      let(:error) { ActiveRecord::StaleObjectError.new('Revision conflict') }

      before do
        allow(response).to receive(:success?).and_return(true)
        allow_any_instance_of(Yes::Core::CommandHandling::ReadModelUpdater)
          .to receive(:call)
          .and_raise(error)
      end

      it 're-raises the error' do
        expect { handler.call(command_name, payload) }.to raise_error(error)
      end
    end
  end
end