# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::Attribute do
  let(:context) { 'TestContext' }
  let(:aggregate) { 'TestAggregate' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }

  describe '.define' do
    subject { described_class.define(attribute_name, attribute_type, **options) }

    after do
      TestContext.send(:remove_const, :TestAggregate) if TestContext.const_defined?(:TestAggregate)
    end

    it 'creates and registers command, event, and handler classes' do
      expect { subject }.to change {
        Object.const_defined?('TestContext::TestAggregate::Commands::ChangeTestField::Command')
      }.from(false).to(true).
        and change {
              Object.const_defined?('TestContext::TestAggregate::Events::TestFieldChanged')
            }.from(false).to(true).
        and change {
              Object.const_defined?('TestContext::TestAggregate::Commands::ChangeTestField::Handler')
            }.from(false).to(true)
    end
  end

  describe '#generate_command_class' do
    subject { described_class.new(attribute_name, attribute_type, options).send(:generate_command_class) }

    let(:test_aggregate_id) { SecureRandom.uuid }

    after do
      TestContext.send(:remove_const, :TestAggregate) if TestContext.const_defined?(:TestAggregate)
    end

    it 'generates a command class with correct attributes' do
      command_class = subject

      expect(command_class.superclass).to eq(Yes::Command)
      expect(command_class.schema.key?(:test_aggregate_id)).to be true
      expect(command_class.schema.key?(:test_field)).to be true
    end

    it 'defines subject_id alias method' do
      command_class = subject
      command = command_class.new(test_aggregate_id:, test_field: 'value')

      expect(command.subject_id).to eq(test_aggregate_id)
    end
  end

  describe '#generate_event_class' do
    subject { described_class.new(attribute_name, attribute_type, options).send(:generate_event_class) }

    let(:test_aggregate_id) { SecureRandom.uuid }
    let(:test_field) { 'value' }

    after do
      TestContext.send(:remove_const, :TestAggregate) if TestContext.const_defined?(:TestAggregate)
    end

    it 'generates an event class with correct schema' do
      event_class = subject
      event = event_class.new(data: { test_aggregate_id:, test_field: })
      schema = event.schema

      expect(schema.rules.keys).to include(:test_aggregate_id, :test_field)
    end
  end

  describe '#generate_handler_class' do
    subject { described_class.new(attribute_name, attribute_type, options).send(:generate_handler_class) }

    after do
      TestContext.send(:remove_const, :TestAggregate) if TestContext.const_defined?(:TestAggregate)
    end

    it 'generates a handler class with correct event name' do
      handler_class = subject

      expect(handler_class.event_name).to eq('TestFieldChanged')
    end

    it 'defines check method for no-change validation' do
      handler_class = subject

      expect(handler_class.instance_methods).to include(:check_test_field_is_not_changing)
    end
  end
end
