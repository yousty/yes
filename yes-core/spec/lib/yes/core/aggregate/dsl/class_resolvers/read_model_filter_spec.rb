# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::ReadModelFilter do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:read_model_name) { 'User' }
  let(:aggregate_class_name) { "#{context}::#{aggregate}::Aggregate" }

  subject { described_class.new(read_model_name, context, aggregate).call }

  describe '#call' do
    it 'resolves filter class inheriting from Yousty::Eventsourcing::ReadModelFilter' do
      expect(subject.superclass).to eq(Yousty::Eventsourcing::ReadModelFilter)
    end

    it 'defines private read_model_class method' do
      expect(subject.private_instance_methods).to include(:read_model_class)
    end

    it 'defines ids scope' do
      expect(subject.private_instance_methods).to include(:read_model_class)
    end

    describe 'filter instance' do
      let(:subject) { super().new(:anything) }

      describe 'read_model_class' do
        let(:subject) { super().send(:read_model_class) }

        before do
          allow(aggregate_class_name.constantize).to receive(:read_model_class)
          subject
        end

        it 'configures read_model_class to return correct class' do
          expect(aggregate_class_name.constantize).to have_received(:read_model_class)
        end
      end

      describe 'ids scope' do
        let(:subject) { super().scopes_configuration }

        it 'defines the ids scope on the class' do
          expect(subject.keys).to include(:ids)
        end
      end
    end
  end
end
