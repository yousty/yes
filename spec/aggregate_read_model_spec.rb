# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Aggregate do
  let(:aggregate_class) { Test::User::Aggregate }

  describe '.read_model' do
    subject { aggregate_class.read_model 'custom_model' }

    before do
      subject
    end

    it 'sets custom read model name' do
      expect(aggregate_class.read_model_name).to eq('custom_model')
    end

    context 'when public is not provided' do
      it 'sets read model visibility to true' do
        expect(aggregate_class.read_model_public?).to be true
      end
    end

    context 'when public is false' do
      subject { aggregate_class.read_model 'custom_model', public: false }
      it 'sets read model visibility to false' do
        expect(aggregate_class.read_model_public?).to be false
      end
    end

    context 'when public is true' do
      subject { aggregate_class.read_model 'custom_model', public: true }

      it 'sets read model visibility to true' do
        expect(aggregate_class.read_model_public?).to be true
      end
    end
  end

  describe 'attribute changes' do
    subject { aggregate.change_name(name: 'New Name') }
    let(:aggregate) { aggregate_class.new }

    before do
      # reset default read model name
      aggregate_class.read_model 'user'
    end

    context 'when attribute change is allowed' do
      before do
        allow(aggregate).to receive(:update_read_model)
      end

      it 'updates read model after successful attribute change' do
        subject
        expect(aggregate).to have_received(:update_read_model).with(name: 'New Name')
      end
    end

    context 'when attribute change is not allowed' do
      before do
        allow(aggregate).to receive(:update_read_model)
        allow(aggregate).to receive(:can_change_name?).and_return(false)
      end

      it 'does not update read model' do
        subject
        expect(aggregate).not_to have_received(:update_read_model)
      end
    end
  end
end
