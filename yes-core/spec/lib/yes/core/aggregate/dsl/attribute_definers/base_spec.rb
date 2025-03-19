# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiners::Base do
  subject(:definer) { described_class.new(attribute_data) }

  let(:attribute_data) { instance_double('Yes::Core::Aggregate::Dsl::AttributeData') }

  describe '#call' do
    before do
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::Command).to receive(:new).and_return(command_resolver)
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::Event).to receive(:new).and_return(event_resolver)
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::GuardEvaluator).to receive(:new).and_return(guard_evaluator_resolver)
    end

    let(:command_resolver) do
      instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::Command', call: true)
    end
    let(:event_resolver) { instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::Event', call: true) }
    let(:guard_evaluator_resolver) do
      instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Attribute::GuardEvaluator', call: true)
    end

    it 'defines classes using the class resolvers' do
      expect { definer.call }.to raise_error(NotImplementedError)

      expect(command_resolver).to have_received(:call)
      expect(event_resolver).to have_received(:call)
      expect(guard_evaluator_resolver).to have_received(:call)
    end

    it 'requires subclasses to implement define_methods' do
      expect { definer.call }.to raise_error(NotImplementedError, /must implement #define_methods/)
    end
  end
end
