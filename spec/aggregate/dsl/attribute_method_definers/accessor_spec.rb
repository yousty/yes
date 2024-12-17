# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::AttributeMethodDefiners::Accessor do
  subject(:definer) { described_class.new(attribute_name, aggregate_class) }

  let(:attribute_name) { :test_field }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:read_model) { instance_double('ReadModel', test_field: 'test value') }
  let(:aggregate_instance) { aggregate_class.new }

  before do
    allow(aggregate_instance).to receive(:read_model).and_return(read_model)
  end

  describe '#call' do
    before do
      definer.call
    end

    it 'defines a reader method for the attribute' do
      expect(aggregate_instance).to respond_to(:test_field)
    end

    it 'delegates to the read model' do
      expect(aggregate_instance.test_field).to eq('test value')
      expect(read_model).to have_received(:test_field)
    end
  end
end 