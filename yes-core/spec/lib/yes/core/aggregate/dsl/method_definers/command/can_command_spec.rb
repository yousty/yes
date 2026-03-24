# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::MethodDefiners::Command::CanCommand do
  subject { described_class.new(command_data).call }

  let(:payload_attributes) { { document_ids: :string, another: :string } }
  let(:command_data) do
    Yes::Core::Aggregate::Dsl::CommandData.new(
      command_name,
      aggregate_class,
      context: 'Test',
      aggregate: 'User',
      payload_attributes:
    )
  end

  let(:aggregate_class) { Test::User::Aggregate }
  let(:command_name) { :approve_documents }
  let(:another) { 'test_value' }

  let(:aggregate) { aggregate_class.new }

  describe '#call' do
    before do
      aggregate_class.remove_method(:"can_#{command_name}?") if aggregate_class.method_defined?(:"can_#{command_name}?")
      aggregate_class.remove_method(:"#{command_name}_error") if aggregate_class.method_defined?(:"#{command_name}_error")

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

    context 'when using Hash payload' do
      let(:payload) { { another: 'test_value' } }
      let(:payload_attributes) { { another: :string } }

      it 'returns true' do
        expect(aggregate.can_some_custom_command?(payload)).to be(true)
      end

      context 'when command takes locale param' do
        let(:payload) { { locale_test: 'new description' } }
        let(:payload_attributes) { { locale_test: :string, locale: :locale } }

        it 'returns true' do
          expect(aggregate.can_test_command_with_locale?(payload)).to be(true)
        end
      end

      context 'when command has default payload' do
        let(:payload) { {} }
        let(:payload_attributes) { { default_payload_test: { type: :string, default: 'foo' } } }

        it 'returns true' do
          expect(aggregate.can_test_command_with_default_payload?(payload)).to be(true)
        end
      end
    end

    context 'when using shorthand value payload' do
      let(:payload) { another }
      let(:command_name) { :some_custom_command }

      context 'when using a single payload attribute' do
        let(:payload_attributes) { { another: :string } }

        it 'returns true' do
          expect(aggregate.can_some_custom_command?(payload)).to be(true)
        end

        context 'when command takes locale param' do
          let(:payload) { 'new description' }
          let(:payload_attributes) { { locale_test: :string, locale: :locale } }

          it 'returns true' do
            expect(aggregate.can_test_command_with_locale?(payload)).to be(true)
          end
        end
      end

      context 'when using multiple payload attributes' do
        it 'raises an error' do
          expect { aggregate.can_approve_documents?(payload) }.
            to raise_error('Payload attributes must be a Hash with a single key (not including locale key)')
        end
      end
    end
  end
end
