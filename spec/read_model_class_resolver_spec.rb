# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::ReadModelClassResolver do
  subject(:resolver) { described_class.new(aggregate_class) }

  let(:aggregate_class) do
    Class.new do
      def self.read_model_name
        'dummy_read_model'
      end
    end
  end

  describe '#resolve' do
    context 'when read model class already exists' do
      before do
        stub_const('DummyReadModel', Class.new(ApplicationRecord))
      end

      it 'returns the existing class' do
        expect(resolver.resolve).to eq(DummyReadModel)
      end

      it 'memoizes the result' do
        first_result = resolver.resolve
        second_result = resolver.resolve
        
        expect(first_result).to eq(second_result)
      end
    end

    context 'when read model class does not exist' do
      after do
        Object.send(:remove_const, 'DummyReadModel') if Object.const_defined?('DummyReadModel')
      end

      it 'generates a new class inheriting from ApplicationRecord' do
        generated_class = resolver.resolve
        
        expect(generated_class.superclass).to eq(ApplicationRecord)
        expect(generated_class.name).to eq('DummyReadModel')
      end

      it 'sets the correct table name' do
        generated_class = resolver.resolve
        
        expect(generated_class.table_name).to eq('dummy_read_models')
      end
    end
  end
end 