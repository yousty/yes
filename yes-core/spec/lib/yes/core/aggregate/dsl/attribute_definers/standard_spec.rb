# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiners::Standard do
  subject(:definer) { described_class.new(attribute_data) }

  let(:attribute_data) do
    instance_double(
      'Yes::Core::Aggregate::Dsl::AttributeData',
      context_name: 'Context', aggregate_name: 'Aggregate', name: :change_x, aggregate_class: Test::User::Aggregate
    )
  end

  describe '#call' do
    before do
      allow(Yes::Core::Aggregate::Dsl::MethodDefiners::Attribute::Accessor).to receive(:new).and_return(accessor)
    end

    let(:accessor) { instance_double('Yes::Core::Aggregate::Dsl::MethodDefiners::Attribute::Accessor', call: true) }

    it 'defines standard attribute methods' do
      definer.call

      expect(accessor).to have_received(:call)
    end
  end
end
