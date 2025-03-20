# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::MethodDefiners::Command::CanCommand do
  subject { described_class.new(command_data).call }

  let(:command_data) do
    Yes::Core::Aggregate::Dsl::CommandData.new(
      command_name,
      aggregate_class,
      context: 'Test',
      aggregate: 'User',
      payload_attributes: {
        document_ids: :string,
        another: :string
      }
    )
  end

  let(:aggregate_class) { Test::User::Aggregate }
  let(:command_name) { :approve_documents }

  let(:aggregate) { aggregate_class.new }

  describe '#call' do
    before do
      aggregate_class.remove_method(:"can_#{command_name}?") if aggregate_class.method_defined?(:"can_#{command_name}?")
      if aggregate_class.method_defined?(:"#{command_name}_error")
        aggregate_class.remove_method(:"#{command_name}_error")
      end

      subject
    end

    context 'command class' do
      it 'defines an accessor for command error' do
        expect(aggregate).to respond_to(:approve_documents_error)
        expect(aggregate).to respond_to(:approve_documents_error=)
      end

      it 'defines the can_<command_name>? method' do
        expect(aggregate).to respond_to(:"can_#{command_name}?")
      end
    end

    context 'when executing the can_<command_name>? method' do
      let(:guard_evaluator_class) { Test::User::Commands::ApproveDocuments::GuardEvaluator }
      let(:guard_evaluator) { instance_double(guard_evaluator_class) }
      let(:document_ids) { SecureRandom.uuid }
      let(:another) { 'test_value' }
      let(:payload) { { document_ids:, another: } }

      before do
        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator)
        allow(guard_evaluator).to receive(:call)
        aggregate.can_approve_documents?(payload)
      end

      it 'calls the guard evaluator' do
        expect(guard_evaluator).to have_received(:call)
      end
    end
  end
end
