# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Core::CommandUtilities do
  subject(:instance) { described_class.new(context:, aggregate:, aggregate_id:) }

  let(:context) { 'Test' }
  let(:aggregate) { 'User' }
  let(:aggregate_id) { SecureRandom.uuid }

  describe '#build_command' do
    subject { instance.build_command(command_name, payload) }

    let(:command_name) { :test_field }
    let(:payload) { { test_field: 'test value' } }
    let(:command_class) { Test::User::Commands::ChangeTestField::Command }

    before do
      # Add test_field attribute to the aggregate
      Test::User::Aggregate.attribute :test_field, :string
    end

    after do
      # Clean up test_field attribute
      Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                  Test::User::Aggregate.attributes.except(:test_field))

      # Clean up configuration
      aggregate_classes = Yes::Core.configuration.instance_variable_get(:@aggregate_classes)
      aggregate_classes&.delete(context)
    end

    it 'builds a command with the correct payload' do
      aggregate_failures do
        expect(subject).to be_a(command_class)
        expect(subject.user_id).to eq(aggregate_id)
        expect(subject.test_field).to eq('test value')
      end
    end

    context 'when command class is not found' do
      let(:command_name) { :nonexistent }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, 'Command class not found for change_nonexistent')
      end
    end

    context 'with aggregate attribute id command' do
      let(:command_name) { :location_id }
      let(:location_id) { SecureRandom.uuid }
      let(:payload) { { location_id: location_id } }
      let(:command_class) { Test::User::Commands::ChangeLocation::Command }

      before do
        # Add location attribute to the aggregate
        Test::User::Aggregate.attribute :location, :aggregate, context: 'Test', aggregate: 'Location'
      end

      after do
        # Clean up location attribute
        Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                    Test::User::Aggregate.attributes.except(:location))
      end

      it 'builds a command with the correct payload using the base command name' do
        aggregate_failures do
          expect(subject).to be_a(command_class)
          expect(subject.user_id).to eq(aggregate_id)
          expect(subject.location_id).to eq(location_id)
        end
      end
    end
  end

  describe '#fetch_handler_class' do
    subject { instance.fetch_handler_class(attribute_name) }

    let(:attribute_name) { :test_field }
    let(:handler_class) { Test::User::Commands::ChangeTestField::Handler }

    before do
      # Add test_field attribute to the aggregate
      Test::User::Aggregate.attribute :test_field, :string
    end

    after do
      # Clean up test_field attribute
      Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                  Test::User::Aggregate.attributes.except(:test_field))

      # Clean up configuration
      aggregate_classes = Yes::Core.configuration.instance_variable_get(:@aggregate_classes)
      aggregate_classes&.delete(context)
    end

    it 'returns the correct handler class' do
      expect(subject).to eq(handler_class)
    end

    context 'when handler class is not found' do
      let(:attribute_name) { :nonexistent }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, 'Handler class not found for change_nonexistent')
      end
    end

    context 'with aggregate attribute id' do
      let(:attribute_name) { :location_id }
      let(:handler_class) { Test::User::Commands::ChangeLocation::Handler }

      before do
        # Add location attribute to the aggregate
        Test::User::Aggregate.attribute :location, :aggregate, context: 'Test', aggregate: 'Location'
      end

      after do
        # Clean up location attribute
        Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                    Test::User::Aggregate.attributes.except(:location))
      end

      it 'returns the correct handler class using the base command name' do
        expect(subject).to eq(handler_class)
      end
    end
  end
end
