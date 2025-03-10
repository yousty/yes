# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::ReadModel do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:read_model_name) { 'test_user' }

  subject { described_class.new(read_model_name, context, aggregate).call }

  describe '#call' do
    it 'resolves read model class inheriting from Yes::Core::ApplicationRecord' do
      expect(subject.superclass).to eq(Yes::Core::ApplicationRecord)
    end

    it 'sets the correct table name' do
      expect(subject.table_name).to eq(read_model_name.pluralize)
    end

    it 'defines the by_ids scope' do
      expect(subject.respond_to?(:by_ids)).to be true
    end

    it 'properly scopes records by ids' do
      ids = %w[1 2]
      relation = subject.by_ids(ids)

      expect(relation.to_sql).to include("WHERE \"#{subject.table_name}\".\"id\" IN")
    end
  end
end
