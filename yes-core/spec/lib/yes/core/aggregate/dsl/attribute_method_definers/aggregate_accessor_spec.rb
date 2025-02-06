# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::AggregateAccessor do
  subject { described_class.new(attribute_data).call }

  let(:attribute_name) { :location }
  let(:attribute_type) { :aggregate }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:location_id) { SecureRandom.uuid }
  let(:read_model) { instance_double('ReadModel', location_id:) }
  let(:aggregate_instance) { aggregate_class.new }
  let(:attribute_data) { Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class) }

  before do
    allow(aggregate_instance).to receive(:read_model).and_return(read_model)
  end

  describe '#call' do
    before { subject }

    it 'defines a reader method for the aggregate and the aggregate id' do
      aggregate_failures do
        expect(aggregate_instance).to respond_to(:location)
        expect(aggregate_instance).to respond_to(:location_id)
      end
    end

    describe '#location_id' do
      it 'delegates location_id to the read model' do
        aggregate_failures do
          expect(aggregate_instance.location_id).to eq(location_id)
          expect(read_model).to have_received(:location_id)
        end
      end
    end

    describe '#location' do
      context 'when location_id is present' do
        it 'returns the location aggregate instance' do
          expect(aggregate_instance.location.class.name).to eq('Test::Location::Aggregate')
        end
      end

      context 'when location_id is nil' do
        let(:location_id) { nil }

        it 'returns nil' do
          expect(aggregate_instance.location).to be_nil
        end
      end
    end
  end
end
