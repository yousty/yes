# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::AttributeMethodDefiners::ChangeCommand do
  subject { instance.call }

  let(:instance) { described_class.new(attribute_data) }
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :test_field }
  let(:attribute_type) { :string }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:command_name) { :change_test_field }
  let(:attribute_data) { Yes::Aggregate::DSL::AttributeData.new(attribute_name, attribute_type, aggregate_class) }

  before do
    # Set up the namespace, handler and command classes
    Test::User::Commands.const_set(:ChangeTestField, Module.new)
    Test::User::Commands::ChangeTestField.const_set(:Handler, Class.new(Yes::CommandHandler))
    Test::User::Commands::ChangeTestField.const_set(:Command, Class.new(Yes::Command))

    # Register the command and handler classes
    Yes.configuration.register_aggregate_class(context, aggregate, command_name, :command,
                                               Test::User::Commands::ChangeTestField::Command)
    Yes.configuration.register_aggregate_class(context, aggregate, command_name, :handler,
                                               Test::User::Commands::ChangeTestField::Handler)

    # Define the can_change method
    Yes::Aggregate::DSL::AttributeMethodDefiners::CanChangeCommand.new(attribute_data).call

    # Define the attribute accessor method
    Yes::Aggregate::DSL::AttributeMethodDefiners::Accessor.new(attribute_data).call
  end

  after do
    Test::User::Commands.send(:remove_const, :ChangeTestField) if Test::User::Commands.const_defined?(:ChangeTestField)
  end

  describe '#call' do
    let(:aggregate_instance) { aggregate_class.new }

    it 'defines a change method for the attribute' do
      subject
      expect(aggregate_instance).to respond_to(:change_test_field)
    end

    describe '#change_test_field' do
      subject { aggregate_instance.change_test_field(**command_payload) }

      let(:handler_class) { Test::User::Commands::ChangeTestField::Handler }
      let(:handler_instance) { instance_double(handler_class) }
      let(:command_payload) { { test_field: 'New Value' } }

      let(:attribute_setup) do
        instance.call
      end

      before do
        attribute_setup

        allow(handler_class).to receive(:new).and_return(handler_instance)
        allow(handler_instance).to receive(:call).and_return(true)
        allow(handler_instance).to receive(:revision_check)
        allow(aggregate_instance).to receive(:can_change_test_field?).and_return(true)
      end

      it 'instantiates and calls the handler with the command' do
        subject

        expect(handler_instance).to have_received(:call)
      end

      it 'updates the read model' do
        subject
        expect(aggregate_instance.test_field).to eq('New Value')
      end
    end
  end
end
