# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Aggregate do
  # use Class.new to reset the class between tests
  let(:subject_class) { Class.new(described_class) }

  describe '.parent' do
    subject { subject_class.parent(:test_parent, option: 'value') }

    it 'adds parent to parent_aggregates' do
      expect { subject }.to change { subject_class.parent_aggregates[:test_parent] }.to(option: 'value')
    end
  end

  describe '.parent_aggregates' do
    subject { subject_class.parent_aggregates }

    it 'returns an empty hash' do
      is_expected.to eq({})
    end
  end

  describe '.primary_context' do
    subject { subject_class.primary_context('TestContext') }

    it 'sets the primary context' do
      expect { subject }.to change { subject_class._primary_context }.to('TestContext')
    end
  end
end
