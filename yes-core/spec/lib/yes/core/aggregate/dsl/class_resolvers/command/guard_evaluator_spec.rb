# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command::GuardEvaluator do
  subject { described_class.new(command_data) }

  let(:aggregate_class) { Class.new }
  let(:command_data) do
    Yes::Core::Aggregate::Dsl::CommandData.new(
      :create_user,
      aggregate_class,
      context: 'UserManagement',
      aggregate: 'User',
      payload_attributes: {
        email: :string,
        name: :string
      }
    )
  end

  let(:context) { 'UserManagement' }
  let(:aggregate) { 'User' }

  after do
    # Clean up constants to ensure test isolation
    Object.send(:remove_const, 'UserManagement') if Object.const_defined?(:UserManagement)
  end

  describe '#class_type' do
    it 'returns :guard_evaluator' do
      expect(subject.send(:class_type)).to eq(:guard_evaluator)
    end
  end

  describe '#class_name' do
    it 'returns the command name' do
      expect(subject.send(:class_name)).to eq(:create_user)
    end
  end

  describe '#generate_class' do
    let(:generated_class) { subject.send(:generate_class) }

    it 'generates a class inheriting from GuardEvaluator' do
      expect(generated_class).to be < Yes::Core::CommandHandling::GuardEvaluator
    end

    it 'includes a no_change guard' do
      expect(generated_class.guards.pluck(:name)).to include(:no_change)
    end

    context 'no change guard evaluation' do
      let(:payload) { { document_ids: '123,456', another: 'John' } }
      let(:aggregate) { Test::User::Aggregate.new }
      let(:instance) { generated_class.new(payload:, aggregate:, command_name: :approve_documents) }
      let(:guard) { generated_class.guards.find { |g| g[:name] == :no_change } }

      let(:command_data) do
        Yes::Core::Aggregate::Dsl::CommandData.new(
          :approve_documents,
          aggregate_class,
          context: 'UserManagement',
          aggregate: 'User',
          payload_attributes: {
            document_ids: :string,
            another: :string
          }
        )
      end

      before do
        # Setup the state updater class which is required in the guard evaluation
        Yes::Core::Aggregate::Dsl::ClassResolvers::Command::StateUpdater.new(command_data).call
      end

      context 'when the command changes the state' do
        it 'passes the guard evaluation' do
          expect { instance.send(:evaluate_guard, guard) }.not_to raise_error
        end
      end

      context 'when the command does not change the state' do
        before do
          aggregate.approve_documents(document_ids: payload[:document_ids], another: payload[:another])
        end

        it 'raises a NoChangeTransition error' do
          expect { instance.send(:evaluate_guard, guard) }.to(
            raise_error(Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition)
          )
        end
      end
    end
  end
end
