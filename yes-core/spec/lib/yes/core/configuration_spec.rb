# frozen_string_literal: true

RSpec.describe Yes::Core::Configuration do
  let(:context_name) { :sales }
  let(:aggregate_name) { :user }
  let(:action_name) { :create }
  let(:test_class) { Class.new }
  let(:configuration) { described_class.new }

  describe '.configuration' do
    subject { Yes::Core.configuration }

    it { is_expected.to be_a(described_class) }
    it { is_expected.to eq(Yes::Core.configuration) }
  end

  describe '#register_command_class' do
    subject { configuration.register_command_class(context_name, aggregate_name, action_name, test_class) }

    it 'registers the command class' do
      subject
      expect(configuration.aggregate_class(context_name, aggregate_name, action_name, :command)).to eq(test_class)
    end
  end

  describe '#register_event_class' do
    subject { configuration.register_event_class(context_name, aggregate_name, action_name, test_class) }

    it 'registers the event class' do
      subject
      expect(configuration.aggregate_class(context_name, aggregate_name, action_name, :event)).to eq(test_class)
    end
  end

  describe '#register_guard_evaluator_class' do
    subject { configuration.register_guard_evaluator_class(context_name, aggregate_name, action_name, test_class) }

    it 'registers the guard evaluator class' do
      subject
      expect(configuration.aggregate_class(context_name, aggregate_name, action_name,
                                           :guard_evaluator)).to eq(test_class)
    end
  end

  describe '#aggregate_class' do
    subject { configuration.aggregate_class(context_name, aggregate_name, action_name, :command) }

    context 'when class is registered' do
      before { configuration.register_command_class(context_name, aggregate_name, action_name, test_class) }

      it { is_expected.to eq(test_class) }
    end
  end

  describe '#aggregate_class' do
    subject { configuration.aggregate_class(context_name, aggregate_name, action_name, :command) }

    context 'when class is registered' do
      before { configuration.register_command_class(context_name, aggregate_name, action_name, test_class) }

      it { is_expected.to eq(test_class) }
    end

    context 'when class is not registered' do
      it { is_expected.to be_nil }
    end
  end

  describe '#list_aggregate_classes' do
    subject { configuration.list_aggregate_classes(context_name, aggregate_name) }

    before do
      configuration.register_command_class(context_name, aggregate_name, :create, test_class)
      configuration.register_event_class(context_name, aggregate_name, :created, test_class)
    end

    it { is_expected.to include(command: { create: test_class }, event: { created: test_class }) }
    it { expect(subject[:handler]).to be_empty }
  end

  describe '#list_all_registered_classes' do
    subject { configuration.list_all_registered_classes }

    let(:another_aggregate) { :order }

    before do
      configuration.register_command_class(context_name, aggregate_name, :create, test_class)
      configuration.register_event_class(context_name, another_aggregate, :created, test_class)
    end

    it do
      is_expected.to eq({
                          [context_name, aggregate_name] => { command: { create: test_class } },
                          [context_name, another_aggregate] => { event: { created: test_class } }
                        })
    end
  end
end
