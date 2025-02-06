# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::Accessor do
  subject { described_class.new(attribute_data).call }

  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:read_model) { instance_double('ReadModel', test_field: 'test value') }
  let(:aggregate_instance) { aggregate_class.new }
  let(:attribute_data) { Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class) }

  before do
    allow(aggregate_instance).to receive(:read_model).and_return(read_model)
  end

  describe '#call' do
    before { subject }

    it 'defines a reader method for the attribute' do
      expect(aggregate_instance).to respond_to(:test_field)
    end

    it 'delegates to the read model' do
      aggregate_failures do
        expect(aggregate_instance.test_field).to eq('test value')
        expect(read_model).to have_received(:test_field)
      end
    end
  end
end
