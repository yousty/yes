# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::GuardRunner do
  subject(:guard_runner) { described_class.new(aggregate) }

  let(:aggregate) { instance_double(Test::User::Aggregate, class: aggregate_class) }
  let(:aggregate_class) { class_double(Test::User::Aggregate, context: 'Test', aggregate: 'User') }
  let(:command) do
    instance_double(
      Yes::Core::Command,
      payload: { document_ids: '123', another: 'value' },
      metadata: { user_id: 'user-456' }
    )
  end
  let(:guard_evaluator_class) { class_double(Yes::Core::CommandHandling::GuardEvaluator) }
  let(:guard_evaluator) do
    instance_double(
      Yes::Core::CommandHandling::GuardEvaluator,
      call: nil,
      accessed_external_aggregates: []
    )
  end
  let(:command_helper) do
    double(
      'Yousty::Eventsourcing::CommandHelper',
      command_name: 'ApproveDocuments'
    )
  end

  before do
    allow(Yousty::Eventsourcing::CommandHelper).to receive(:new).with(command).and_return(command_helper)
  end

  describe '#call' do
    context 'when guards should be evaluated' do
      before do
        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator)
        allow(aggregate).to receive(:send)
      end

      it 'creates and calls the guard evaluator' do
        result = guard_runner.call(command, guard_evaluator_class, skip_guards: false)

        aggregate_failures do
          expect(guard_evaluator_class).to have_received(:new).with(
            payload: command.payload,
            metadata: command.metadata,
            aggregate: aggregate,
            command_name: 'ApproveDocuments'
          )
          expect(guard_evaluator).to have_received(:call)
          expect(result).to eq(guard_evaluator)
        end
      end

      it 'clears command error on success' do
        guard_runner.call(command, guard_evaluator_class, skip_guards: false)

        expect(aggregate).to have_received(:send).with(:approve_documents_error=, nil)
      end

      context 'when guard evaluation raises InvalidTransition' do
        let(:error) { Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition.new('Invalid state') }

        before do
          allow(guard_evaluator).to receive(:call).and_raise(error)
        end

        it 'sets error on aggregate and re-raises' do
          aggregate_failures do
            expect {
              guard_runner.call(command, guard_evaluator_class, skip_guards: false)
            }.to raise_error(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)

            expect(aggregate).to have_received(:send).with(:approve_documents_error=, 'Invalid state')
          end
        end
      end

      context 'when guard evaluation raises NoChangeTransition' do
        let(:error) { Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition.new('No change') }

        before do
          allow(guard_evaluator).to receive(:call).and_raise(error)
        end

        it 'sets error on aggregate and re-raises' do
          aggregate_failures do
            expect {
              guard_runner.call(command, guard_evaluator_class, skip_guards: false)
            }.to raise_error(Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition)

            expect(aggregate).to have_received(:send).with(:approve_documents_error=, 'No change')
          end
        end
      end

      context 'when command is invalid' do
        let(:error) { Yousty::Eventsourcing::Command::Invalid.new('Invalid command') }

        before do
          allow(guard_evaluator).to receive(:call).and_raise(error)
        end

        it 'sets error on aggregate and re-raises' do
          aggregate_failures do
            expect {
              guard_runner.call(command, guard_evaluator_class, skip_guards: false)
            }.to raise_error(Yousty::Eventsourcing::Command::Invalid)

            expect(aggregate).to have_received(:send).with(:approve_documents_error=, 'Invalid command')
          end
        end
      end
    end

    context 'when guards should be skipped' do
      before do
        allow(aggregate).to receive(:send)
        allow(guard_evaluator_class).to receive(:new)
      end

      it 'returns nil without creating evaluator' do
        result = guard_runner.call(command, guard_evaluator_class, skip_guards: true)

        aggregate_failures do
          expect(guard_evaluator_class).not_to have_received(:new)
          expect(result).to be_nil
        end
      end

      it 'still clears command error' do
        guard_runner.call(command, guard_evaluator_class, skip_guards: true)

        expect(aggregate).to have_received(:send).with(:approve_documents_error=, nil)
      end
    end

    context 'with different command names' do
      let(:command_helper) do
        double(
          'Yousty::Eventsourcing::CommandHelper',
          command_name: 'UpdateUserProfile'
        )
      end

      before do
        allow(guard_evaluator_class).to receive(:new).and_return(guard_evaluator)
        allow(aggregate).to receive(:send)
      end

      it 'uses underscored command name for error setter' do
        guard_runner.call(command, guard_evaluator_class, skip_guards: false)

        expect(aggregate).to have_received(:send).with(:update_user_profile_error=, nil)
      end

      context 'when error occurs' do
        let(:error) { Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition.new('Error message') }

        before do
          allow(guard_evaluator).to receive(:call).and_raise(error)
        end

        it 'sets error with underscored command name' do
          aggregate_failures do
            expect {
              guard_runner.call(command, guard_evaluator_class, skip_guards: false)
            }.to raise_error(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)

            expect(aggregate).to have_received(:send).with(:update_user_profile_error=, 'Error message')
          end
        end
      end
    end
  end

  describe 'initialization' do
    it 'initializes with an aggregate' do
      expect(guard_runner).to be_a(described_class)
    end
  end

  describe 'error handling with real objects' do
    let(:aggregate) { Test::User::Aggregate.new(SecureRandom.uuid) }
    let(:command) do
      double(
        'Command',
        payload: { document_ids: '123', another: 'value' },
        metadata: {}
      )
    end
    let(:guard_runner) { described_class.new(aggregate) }

    before do
      allow(Yousty::Eventsourcing::CommandHelper).to receive(:new)
        .with(command)
        .and_return(double(command_name: 'ApproveDocuments'))
    end

    context 'with guard evaluator that raises errors' do
      let(:failing_guard_evaluator) do
        Class.new(Yes::Core::CommandHandling::GuardEvaluator) do
          def call
            raise Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition, 'Test error'
          end
        end
      end

      it 'propagates the error and sets it on aggregate' do
        aggregate_failures do
          expect {
            guard_runner.call(command, failing_guard_evaluator, skip_guards: false)
          }.to raise_error(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition, 'Test error')

          expect(aggregate.approve_documents_error).to eq('Test error')
        end
      end
    end

    context 'with successful guard evaluation' do
      let(:successful_guard_evaluator) do
        Class.new(Yes::Core::CommandHandling::GuardEvaluator) do
          def call
            # Success - no error raised
          end
        end
      end

      before do
        # Set an error first to verify it gets cleared
        aggregate.approve_documents_error = 'Previous error'
      end

      it 'clears any existing error on aggregate' do
        guard_runner.call(command, successful_guard_evaluator, skip_guards: false)

        expect(aggregate.approve_documents_error).to be_nil
      end
    end
  end
end