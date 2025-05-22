# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiners::Aggregate do
  subject { instance.call }

  let(:instance) { described_class.new(attribute_data) }
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :location }
  let(:attribute_type) { :aggregate }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:attribute_data) do
    Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class, options)
  end

  before do
    Test::User::Aggregate.attribute :location, :aggregate
  end

  after do
    # Clean up location attribute
    Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                Test::User::Aggregate.attributes.except(:location))
  end

  describe '#call' do
    let(:aggregate_instance) { aggregate_class.new }

    it 'defines methods to access aggregate and aggregate id' do
      subject
      aggregate_failures do
        expect(aggregate_instance).to respond_to(:location)
        expect(aggregate_instance).to respond_to(:location_id)
      end
    end
  end
end
