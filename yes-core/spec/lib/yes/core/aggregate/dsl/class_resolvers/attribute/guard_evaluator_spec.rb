# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::GuardEvaluator do
  subject { described_class.new(attribute_data) }

  let(:context_name) { 'Test' }
  let(:aggregate_name) { 'User' }
  let(:attribute_name) { :email }
  let(:attribute_type) { :string }
  let(:options) { { context: context_name, aggregate: aggregate_name } }
  let(:aggregate_class) { Test::User::Aggregate }

  let(:attribute_data) do
    Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class, options)
  end

  describe '#class_type' do
    it 'returns :guard_evaluator' do
      expect(subject.send(:class_type)).to eq(:guard_evaluator)
    end
  end

  describe '#class_name' do
    it 'returns the command name from the attribute' do
      expect(subject.send(:class_name)).to eq(:change_email)
    end
  end

  describe '#generate_class' do
    let(:generated_class) { subject.send(:generate_class) }

    before do
      allow(subject).to receive(:aggregate_name).and_return(aggregate_name)
    end

    it 'generates a class inheriting from GuardEvaluator' do
      expect(generated_class).to be < Yes::Core::CommandHandling::GuardEvaluator
    end

    it 'includes a no_change guard' do
      expect(generated_class.guards.pluck(:name)).to include(:no_change)
    end

    context 'no change guard evaluation' do
      let(:aggregate) { Test::User::Aggregate.new }
      let(:instance) { generated_class.new(payload:, aggregate:, command_name: :change_email) }
      let(:guard) { generated_class.guards.find { |g| g[:name] == :no_change } }

      context 'with standard attribute type' do
        let(:payload) { { email: 'new@email.com' } }

        context 'when the command changes the state' do
          it 'passes the guard evaluation' do
            expect { instance.send(:evaluate_guard, guard) }.not_to raise_error
          end
        end

        context 'when the command does not change the state' do
          before do
            aggregate.change_email(email: payload[:email])
          end

          it 'raises a NoChangeTransition error' do
            expect { instance.send(:evaluate_guard, guard) }.to(
              raise_error(Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition)
            )
          end
        end
      end

      context 'with aggregate attribute type' do
        let(:attribute_type) { :aggregate }
        let(:attribute_name) { 'location' }
        let(:new_id) { SecureRandom.uuid }
        let(:payload) { { location_id: new_id } }

        before do
          Test::User::Aggregate.attribute :location, :aggregate, command: true
        end

        after do
          Test::User::Aggregate.singleton_class.instance_variable_set(
            :@attributes,
            Test::User::Aggregate.attributes.except(:location)
          )
        end

        context 'when the command changes the state' do
          it 'passes the guard evaluation' do
            expect { instance.send(:evaluate_guard, guard) }.not_to raise_error
          end
        end

        context 'when the command does not change the state' do
          before do
            aggregate.change_location_id(location_id: payload[:location_id])
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
end
