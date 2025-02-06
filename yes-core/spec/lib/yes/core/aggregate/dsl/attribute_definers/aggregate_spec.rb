# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiners::Aggregate do
  subject { instance.call }

  let(:instance) { described_class.new(attribute_data) }
  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:attribute_name) { :location }
  let(:attribute_type) { :aggregate }
  let(:options) { { context:, aggregate: } }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:command_name) { :change_location }
  let(:attribute_data) do
    Yes::Core::Aggregate::Dsl::AttributeData.new(attribute_name, attribute_type, aggregate_class, options)
  end

  before do
    # Set up the namespace, handler and command classes
    Test::User::Commands.const_set(:ChangeLocation, Module.new)
    Test::User::Commands::ChangeLocation.const_set(:Handler, Class.new(Yes::Core::CommandHandler))
    Test::User::Commands::ChangeLocation.const_set(:Command, Class.new(Yes::Core::Command))

    # Register the command and handler classes
    Yes::Core.configuration.register_aggregate_class(context, aggregate, command_name, :command,
                                                     Test::User::Commands::ChangeLocation::Command)
    Yes::Core.configuration.register_aggregate_class(context, aggregate, command_name, :handler,
                                                     Test::User::Commands::ChangeLocation::Handler)

    # Define the can_change method
    Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::CanChangeCommand.new(attribute_data).call

    # Define the attribute accessor method
    Yes::Core::Aggregate::Dsl::AttributeMethodDefiners::AggregateAccessor.new(attribute_data).call
  end

  after do
    # Clean up command and handler classes
    if Test::User::Commands.const_defined?(:ChangeLocation)
      if Test::User::Commands::ChangeLocation.const_defined?(:Handler)
        Test::User::Commands::ChangeLocation.send(:remove_const, :Handler)
      end
      if Test::User::Commands::ChangeLocation.const_defined?(:Command)
        Test::User::Commands::ChangeLocation.send(:remove_const, :Command)
      end
      Test::User::Commands.send(:remove_const, :ChangeLocation)
    end

    # Clean up configuration
    aggregate_classes = Yes::Core.configuration.instance_variable_get(:@aggregate_classes)
    aggregate_classes&.delete(context)
  end

  describe '#call' do
    let(:aggregate_instance) { aggregate_class.new }

    it 'defines a change method for the attribute' do
      subject
      expect(aggregate_instance).to respond_to(:change_location)
    end

    it 'defines both can_change methods' do
      subject
      aggregate_failures do
        expect(aggregate_instance).to respond_to(:can_change_location?)
        expect(aggregate_instance).to respond_to(:can_change_location_id?)
      end
    end

    describe '#change_location' do
      subject { aggregate_instance.change_location(**command_payload) }

      let(:handler_class) { Test::User::Commands::ChangeLocation::Handler }
      let(:handler_instance) { instance_double(handler_class) }
      let(:location_id) { SecureRandom.uuid }
      let(:location_aggregate) { instance_double('Test::Location::Aggregate', id: location_id) }
      let(:command_payload) { { location: location_aggregate } }

      let(:attribute_setup) do
        instance.call
      end

      before do
        attribute_setup

        allow(handler_class).to receive(:new).and_return(handler_instance)
        allow(handler_instance).to receive(:call).and_return(true)
        allow(handler_instance).to receive(:revision_check)
      end

      it 'instantiates and calls the handler with the command' do
        subject

        # one time for calling actual handler code, one time for publishing events only
        expect(handler_instance).to have_received(:call).twice
      end

      it 'updates the read model with the aggregate ID' do
        subject
        expect(aggregate_instance.location_id).to eq(location_id)
      end

      context 'when the handler raises an error' do
        before do
          allow(handler_instance).to receive(:call).and_raise(Yes::Core::CommandHandler::InvalidTransition,
                                                              'test error')
        end

        it 'does not update the read model' do
          original_id = aggregate_instance.location_id
          subject
          expect(aggregate_instance.location_id).to eq(original_id)
        end
      end
    end

    describe '#change_location_id' do
      subject { aggregate_instance.change_location_id(**command_payload) }

      let(:handler_class) { Test::User::Commands::ChangeLocation::Handler }
      let(:handler_instance) { instance_double(handler_class) }
      let(:location_id) { SecureRandom.uuid }
      let(:command_payload) { { location_id: location_id } }

      let(:attribute_setup) do
        instance.call
      end

      before do
        attribute_setup

        allow(handler_class).to receive(:new).and_return(handler_instance)
        allow(handler_instance).to receive(:call).and_return(true)
        allow(handler_instance).to receive(:revision_check)
      end

      it 'instantiates and calls the handler with the command' do
        subject

        # one time for calling actual handler code, one time for publishing events only
        expect(handler_instance).to have_received(:call).twice
      end

      it 'updates the read model with the ID' do
        subject
        expect(aggregate_instance.location_id).to eq(location_id)
      end

      context 'when the handler raises an error' do
        before do
          allow(handler_instance).to receive(:call).and_raise(Yes::Core::CommandHandler::InvalidTransition,
                                                              'test error')
        end

        it 'does not update the read model' do
          original_id = aggregate_instance.location_id
          subject
          expect(aggregate_instance.location_id).to eq(original_id)
        end
      end
    end

    describe 'can_change methods' do
      let(:handler_class) { Test::User::Commands::ChangeLocation::Handler }
      let(:handler_instance) { instance_double(handler_class) }
      let(:location_id) { SecureRandom.uuid }
      let(:location_aggregate) { instance_double('Test::Location::Aggregate', id: location_id) }

      let(:attribute_setup) do
        instance.call
      end

      before do
        attribute_setup

        allow(handler_class).to receive(:new).and_return(handler_instance)
        allow(handler_instance).to receive(:call).and_return(true)
        allow(handler_instance).to receive(:revision_check)
      end

      it 'checks if the aggregate can be changed' do
        expect(aggregate_instance.can_change_location?(location: location_aggregate)).to be_truthy
      end

      it 'checks if the aggregate ID can be changed' do
        expect(aggregate_instance.can_change_location_id?(location_id: location_id)).to be_truthy
      end

      context 'when the handler raises an error' do
        before do
          allow(handler_instance).to receive(:call).and_raise(Yes::Core::CommandHandler::InvalidTransition,
                                                              'test error')
        end

        it 'indicates the aggregate cannot be changed' do
          expect(aggregate_instance.can_change_location?(location: location_aggregate)).to be_falsey
        end

        it 'indicates the aggregate ID cannot be changed' do
          expect(aggregate_instance.can_change_location_id?(location_id: location_id)).to be_falsey
        end
      end
    end
  end
end
