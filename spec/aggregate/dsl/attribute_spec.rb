# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::Attribute do
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:user_id) { SecureRandom.uuid }

  describe '.define' do
    # define a new attribute on the existing user aggregate
    subject { described_class.define(attribute_name, attribute_type, aggregate_class, **options) }

    it 'creates and registers command, event, and handler classes' do
      expect { subject }.to change {
        Test::User::Commands.const_defined?('ChangeTestField::Command')
      }.from(false).to(true).
        and change {
              Test::User::Events.const_defined?('TestFieldChanged')
            }.from(false).to(true).
        and change {
              Test::User::Commands.const_defined?('ChangeTestField::Handler')
            }.from(false).to(true)
    end

    context 'change command method' do
      it 'defines a change method for the attribute' do
        subject
        expect(aggregate_class.new).to respond_to(:change_test_field)
      end
    end

    context 'can_change...? command method' do
      it 'defines a can_change...? method for the attribute' do
        subject
        expect(aggregate_class.new).to respond_to(:can_change_test_field?)
      end
    end
  end

  describe '#generate_command_class' do
    subject do
      described_class.new(attribute_name, attribute_type, Test::User::Aggregate, options)
                    .send(:generate_command_class)
    end

    it 'generates a command class with correct attributes' do
      command_class = subject

      expect(command_class.superclass).to eq(Yes::Command)
      expect(command_class.schema.key?(:user_id)).to be true
      expect(command_class.schema.key?(:test_field)).to be true
    end

    it 'defines subject_id alias method' do
      command_class = subject
      command = command_class.new(user_id:, test_field: 'value')

      expect(command.subject_id).to eq(user_id)
    end
  end

  describe '#generate_event_class' do
    subject do
      described_class.new(attribute_name, attribute_type, Test::User::Aggregate, options)
                    .send(:generate_event_class)
    end

    let(:test_field) { 'value' }

    it 'generates an event class with correct schema' do
      event_class = subject
      event = event_class.new(data: { user_id:, test_field: })
      schema = event.schema

      expect(schema.rules.keys).to include(:user_id, :test_field)
    end
  end

  describe '#generate_handler_class' do
    subject do
      described_class.new(attribute_name, attribute_type, Test::User::Aggregate, options)
                    .send(:generate_handler_class)
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
