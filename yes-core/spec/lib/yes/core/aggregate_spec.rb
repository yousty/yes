# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate do
  # use Class.new to reset the class between tests
  let(:subject_class) { Test::User::Aggregate }

  describe '.parent' do
    subject { subject_class.parent(:test_parent, option: 'value') }

    after do
      # reset to not mess with further specs
      subject_class.instance_variable_set(:@parent_aggregates, {})
    end

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

  describe '#reload' do
    subject(:reload_call) { instance.reload }

    let(:instance) { subject_class.new }
    let(:read_model_double) { instance_double('ApplicationRecord') }

    before do
      allow(instance).to receive(:read_model).and_return(read_model_double)
      allow(read_model_double).to receive(:reload)
    end

    it 'reloads the read model' do
      reload_call
      expect(read_model_double).to have_received(:reload)
    end

    it 'returns the aggregate instance' do
      expect(reload_call).to eq(instance)
    end
  end
end
