# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::ReadModelSerializer do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:read_model_name) { 'User' }
  let(:read_model_attributes) { %i[email active age name] }
  let(:test_model) do
    Struct.new(*(%i[id] + read_model_attributes)).new(1, 'test@example.com', true, 25, 'Test User')
  end

  subject do
    described_class.new(
      read_model_name,
      context,
      aggregate,
      read_model_attributes
    ).call
  end

  describe '#call' do
    it 'resolves serializer class inheriting from Yousty::Api::ApplicationSerializer' do
      expect(subject.superclass).to eq(Yousty::Api::ApplicationSerializer)
    end

    it 'sets the correct type for JSON:API serialization' do
      expect(subject.record_type).to eq(:users)
    end

    it 'defines the specified attributes' do
      expect(subject.attributes_to_serialize.keys).to match_array(read_model_attributes)
    end
  end
end
