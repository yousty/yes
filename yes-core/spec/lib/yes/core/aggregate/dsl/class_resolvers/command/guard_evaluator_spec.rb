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

    before do
      allow(subject).to receive(:aggregate_name).and_return(aggregate)
    end

    it 'generates a class inheriting from GuardEvaluator' do
      expect(generated_class).to be < Yes::Core::CommandHandling::GuardEvaluator
    end
  end
end
