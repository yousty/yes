# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiners::Base do
  subject(:definer) { described_class.new(attribute_data) }

  let(:attribute_data) do
    instance_double('Yes::Core::Aggregate::Dsl::AttributeData')
  end

  describe '#call' do
    it 'requires subclasses to implement define_methods' do
      expect { definer.call }.to raise_error(NotImplementedError, /must implement #define_methods/)
    end
  end
end
