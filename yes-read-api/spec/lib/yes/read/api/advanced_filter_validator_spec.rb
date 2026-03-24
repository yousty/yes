# frozen_string_literal: true

require_relative '../../../../rails_helper'

RSpec.describe Yes::Read::Api::AdvancedFilterValidator do
  describe '.call' do
    subject { described_class.call(payload) }

    let(:valid_filter_definition) do
      { type: 'filter_set', logical_operator: 'and', filters: [] }
    end

    context 'with valid filter_definition and pagination' do
      let(:payload) do
        {
          filter_definition: valid_filter_definition,
          page: { size: 10, number: 1 }
        }
      end

      it 'returns a successful result' do
        expect(subject).to be_success
      end
    end

    context 'with valid filter_definition without pagination' do
      let(:payload) do
        { filter_definition: valid_filter_definition }
      end

      it 'returns a successful result' do
        expect(subject).to be_success
      end
    end

    context 'with missing filter_definition' do
      let(:payload) { {} }

      it 'returns a failure result' do
        expect(subject).to be_failure
      end

      it 'includes filter_definition error' do
        expect(subject.errors.to_h).to have_key(:filter_definition)
      end
    end

    context 'with invalid pagination (missing size)' do
      let(:payload) do
        {
          filter_definition: valid_filter_definition,
          page: { number: 1 }
        }
      end

      it 'returns a failure result' do
        expect(subject).to be_failure
      end
    end

    context 'with optional order param' do
      let(:payload) do
        {
          filter_definition: valid_filter_definition,
          order: { created_at: 'desc' }
        }
      end

      it 'returns a successful result' do
        expect(subject).to be_success
      end
    end

    context 'with optional include param' do
      let(:payload) do
        {
          filter_definition: valid_filter_definition,
          include: 'company'
        }
      end

      it 'returns a successful result' do
        expect(subject).to be_success
      end
    end
  end
end
