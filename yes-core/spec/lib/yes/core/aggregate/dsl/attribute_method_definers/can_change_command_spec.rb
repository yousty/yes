# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::CanChangeCommand do
  subject { instance.call }

  let(:instance) { described_class.new(attribute_data) }
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:command_payload) { { test_field: 'test value' } }
  let(:handler_class) { Test::User::Commands::ChangeTestField::Handler }
  let(:aggregate_instance) { aggregate_class.new }
  let(:command_name) { :change_test_field }
  let(:attribute_data) { Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class) }

  before do
    # Set up the namespace, handler and command classes
    Test::User::Commands.const_set(:ChangeTestField, Module.new)
    Test::User::Commands::ChangeTestField.const_set(:Handler, Class.new(Yes::Core::CommandHandler))
    Test::User::Commands::ChangeTestField.const_set(:Command, Class.new(Yes::Core::Command))

    # Register the command and handler classes
    Yes::Core.configuration.register_aggregate_class(context, aggregate, command_name, :command,
                                                     Test::User::Commands::ChangeTestField::Command)
    Yes::Core.configuration.register_aggregate_class(context, aggregate, command_name, :handler,
                                                     Test::User::Commands::ChangeTestField::Handler)
  end

  after do
    Test::User::Commands.send(:remove_const, :ChangeTestField) if Test::User::Commands.const_defined?(:ChangeTestField)
  end

  describe '#call' do
    before do
      subject
    end

    it 'defines a can_change method for the attribute' do
      expect(aggregate_instance).to respond_to(:can_change_test_field?)
    end

    it 'defines an error accessor' do
      expect(aggregate_instance).to respond_to(:change_test_field_error)
      expect(aggregate_instance).to respond_to(:change_test_field_error=)
    end

    context 'when validation succeeds' do
      let(:handler_instance) { instance_double(handler_class, call: true) }

      before do
        allow(handler_class).to receive(:new).and_return(handler_instance)
      end

      it 'returns true' do
        expect(aggregate_instance.can_change_test_field?(**command_payload)).to be true
      end

      it 'clears any previous error' do
        aggregate_instance.change_test_field_error = 'Previous error'
        aggregate_instance.can_change_test_field?(**command_payload)
        expect(aggregate_instance.change_test_field_error).to be_nil
      end
    end

    context 'when validation fails' do
      let(:error_message) { 'Validation failed' }
      let(:handler_instance) { instance_double(handler_class) }

      before do
        allow(handler_class).to receive(:new).and_return(handler_instance)
        allow(handler_instance).to receive(:call).and_raise(
          Yes::Core::CommandHandler::InvalidTransition, error_message
        )
      end

      it 'returns false' do
        expect(aggregate_instance.can_change_test_field?(**command_payload)).to be false
      end

      it 'sets the error message' do
        aggregate_instance.can_change_test_field?(**command_payload)
        expect(aggregate_instance.change_test_field_error).to eq(error_message)
      end
    end
  end
end
