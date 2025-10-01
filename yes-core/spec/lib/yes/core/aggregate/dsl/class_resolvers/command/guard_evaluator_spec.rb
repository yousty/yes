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
      expect(generated_class.guards.keys).to include(:no_change)
    end

    context 'no change guard evaluation' do
      let(:payload) { { document_ids: '123,456', another: 'John' } }
      let(:aggregate) { Test::User::Aggregate.new }
      let(:instance) { generated_class.new(payload:, metadata: {}, aggregate:, command_name: :approve_documents) }
      let(:guard_block) { generated_class.guards[:no_change][:block] }

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
          expect { instance.send(:evaluate_guard, :no_change, block: guard_block) }.not_to raise_error
        end
      end

      context 'when the command does not change the state' do
        before do
          aggregate.approve_documents(document_ids: payload[:document_ids], another: payload[:another])
        end

        it 'raises a NoChangeTransition error' do
          expect { instance.send(:evaluate_guard, :no_change, block: guard_block) }.to(
            raise_error(Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition)
          )
        end
      end
    end

    context 'custom guard evaluation' do
      let(:payload) { { shortcut_description: 'foo' } }
      let(:aggregate) { Test::User::Aggregate.new }
      let(:instance) { generated_class.new(payload:, metadata: {}, aggregate:, command_name: :change_shortcut_description) }
      let(:guard_block) { generated_class.guards[:test_guard][:block] }
      let(:extra_block) { generated_class.guards[:test_guard][:error_extra] }
      let(:command_data) do
        Yes::Core::Aggregate::Dsl::CommandData.new(
          :change_shortcut_description,
          aggregate_class,
          context: 'UserManagement',
          aggregate: 'User',
          payload_attributes: {
            shortcut_description: :string
          },
          guard_names: [
            :test_guard
          ]
        )
      end

      before do
        generated_class.guard(
          :test_guard,
          error_extra: proc do
            {
              current_value: shortcut_description,
              new_value: payload.shortcut_description,
              expected_min_length: 4,
              new_value_length: payload.shortcut_description.size
            }
          end
        ) do
          payload.shortcut_description.size > 3
        end
         # Setup the state updater class which is required in the guard evaluation
        Yes::Core::Aggregate::Dsl::ClassResolvers::Command::StateUpdater.new(command_data).call
      end

      context 'when the command payload is invalid' do
        before do
          aggregate.change_shortcut_description(shortcut_description: payload[:shortcut_description])
        end

        it 'raises a InvalidTransition error' do
          expect { instance.send(:evaluate_guard, :test_guard, block: guard_block, error_extra: extra_block) }.to(
            raise_error(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)
          )
        end

        it 'includes the error extra in the error message' do
          expect do
            instance.send(:evaluate_guard, :test_guard, block: guard_block, error_extra: extra_block)
          end.to raise_error(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition) do |error|
            expect(error.extra).to eq(
              current_value: nil,
              new_value: 'foo',
              expected_min_length: 4,
              new_value_length: 3
            )
          end
        end
      end
    end
  end
end
