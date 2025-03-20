# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiners::Standard do
  subject(:definer) { described_class.new(attribute_data) }

  let(:attribute_data) do
    instance_double(
      'Yes::Core::Aggregate::Dsl::AttributeData',
      define_command: true, context_name: 'Context', aggregate_name: 'Aggregate', name: :change_x, event_name: :x_changed
    )
  end

  describe '#call' do
    before do
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::Command).to receive(:new).and_return(command_resolver)
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::Event).to receive(:new).and_return(event_resolver)
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::GuardEvaluator).to(
        receive(:new).and_return(guard_evaluator_resolver)
      )

      allow(Yes::Core::Aggregate::Dsl::MethodDefiners::Attribute::ChangeCommand).to(
        receive(:new).and_return(change_command)
      )
      allow(Yes::Core::Aggregate::Dsl::MethodDefiners::Attribute::CanChangeCommand).to(
        receive(:new).and_return(can_change_command)
      )
      allow(Yes::Core::Aggregate::Dsl::MethodDefiners::Attribute::Accessor).to receive(:new).and_return(accessor)
    end

    let(:command_resolver) do
      instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::Command', call: true)
    end
    let(:event_resolver) do
      instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::Event', call: true)
    end
    let(:guard_evaluator_resolver) do
      instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::GuardEvaluator', call: true)
    end

    let(:change_command) do
      instance_double('Yes::Core::Aggregate::Dsl::MethodDefiners::Attribute::ChangeCommand', call: true)
    end
    let(:can_change_command) do
      instance_double('Yes::Core::Aggregate::Dsl::MethodDefiners::Attribute::CanChangeCommand', call: true)
    end
    let(:accessor) { instance_double('Yes::Core::Aggregate::Dsl::MethodDefiners::Attribute::Accessor', call: true) }

    it 'defines standard attribute methods' do
      definer.call

      expect(change_command).to have_received(:call)
      expect(can_change_command).to have_received(:call)
      expect(accessor).to have_received(:call)
    end
  end
end
