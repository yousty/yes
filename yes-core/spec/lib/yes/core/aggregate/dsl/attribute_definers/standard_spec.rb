# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiners::Standard do
  subject(:definer) { described_class.new(attribute_data) }

  let(:attribute_data) { instance_double('Yes::Core::Aggregate::Dsl::AttributeData') }

  describe '#call' do
    before do
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Command).to receive(:new).and_return(command_resolver)
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Event).to receive(:new).and_return(event_resolver)
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::GuardEvaluator).to(
        receive(:new).and_return(guard_evaluator_resolver)
      )

      allow(Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::ChangeCommand).to(
        receive(:new).and_return(change_command)
      )
      allow(Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::CanChangeCommand).to(
        receive(:new).and_return(can_change_command)
      )
      allow(Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::Accessor).to receive(:new).and_return(accessor)
    end

    let(:command_resolver) { instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Command', call: true) }
    let(:event_resolver) { instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Event', call: true) }
    let(:guard_evaluator_resolver) do
      instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::GuardEvaluator', call: true)
    end

    let(:change_command) do
      instance_double('Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::ChangeCommand', call: true)
    end
    let(:can_change_command) do
      instance_double('Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::CanChangeCommand', call: true)
    end
    let(:accessor) { instance_double('Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::Accessor', call: true) }

    it 'defines standard attribute methods' do
      definer.call

      expect(change_command).to have_received(:call)
      expect(can_change_command).to have_received(:call)
      expect(accessor).to have_received(:call)
    end
  end
end
