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

    context 'with draft parameter' do
      let(:configuration) { Yes::Core.configuration }

      before do
        allow(Yes::Core).to receive(:configuration).and_return(configuration)
        allow(configuration).to receive(:register_read_model_class)
      end

      context 'when draft is false' do
        subject { described_class.new(read_model_name, context, aggregate, draft: false).call }

        it 'registers the class with draft: false' do
          subject
          expect(configuration).to have_received(:register_read_model_class).with(
            context,
            aggregate,
            kind_of(Class),
            draft: false
          )
        end
      end

      context 'when draft is true' do
        subject { described_class.new(read_model_name, context, aggregate, draft: true).call }

        it 'registers the class with draft: true' do
          subject
          expect(configuration).to have_received(:register_read_model_class).with(
            context,
            aggregate,
            kind_of(Class),
            draft: true
          )
        end
      end

      context 'when draft is not specified' do
        subject { described_class.new(read_model_name, context, aggregate).call }

        it 'registers the class with draft: false by default' do
          subject
          expect(configuration).to have_received(:register_read_model_class).with(
            context,
            aggregate,
            kind_of(Class),
            draft: false
          )
        end
      end
    end
  end
end
