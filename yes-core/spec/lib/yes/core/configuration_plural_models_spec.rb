# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Core::Configuration do
  describe 'plural model name handling' do
    let(:configuration) { Yes::Core::Configuration.new }

    before do
      # Clear any existing registrations
      Yes::Core.configuration = configuration
    end

    describe '#all_read_model_class_names' do
      context 'with plural model names' do
        before do
          # Register a test aggregate with plural name
          configuration.register_aggregate_class(:test, :company_settings)
          
          # Mock the aggregate class
          aggregate_class = double('TestCompanySettingsAggregate')
          allow(aggregate_class).to receive(:respond_to?).with(:read_model_name).and_return(true)
          allow(aggregate_class).to receive(:read_model_name).and_return('company_settings')
          allow(aggregate_class).to receive(:respond_to?).with(:changes_read_model_name).and_return(false)
          
          allow(Object).to receive(:const_get).with('Test::CompanySettings::Aggregate').and_return(aggregate_class)
        end

        it 'preserves plural names when using camelize instead of classify' do
          class_names = configuration.all_read_model_class_names
          
          # Should be CompanySettings (plural), not CompanySetting (singular)
          expect(class_names).to include('CompanySettings')
          expect(class_names).not_to include('CompanySetting')
        end
      end

      context 'with singular model names' do
        before do
          # Register a test aggregate with singular name
          configuration.register_aggregate_class(:test, :user)
          
          # Mock the aggregate class
          aggregate_class = double('TestUserAggregate')
          allow(aggregate_class).to receive(:respond_to?).with(:read_model_name).and_return(true)
          allow(aggregate_class).to receive(:read_model_name).and_return('user')
          allow(aggregate_class).to receive(:respond_to?).with(:changes_read_model_name).and_return(false)
          
          allow(Object).to receive(:const_get).with('Test::User::Aggregate').and_return(aggregate_class)
        end

        it 'handles singular names correctly with camelize' do
          class_names = configuration.all_read_model_class_names
          
          # Should be User (singular remains singular)
          expect(class_names).to include('User')
        end
      end

      context 'with mixed plural/singular compound names' do
        before do
          # Register aggregates with compound names
          configuration.register_aggregate_class(:company_management, :user_settings)
          
          # Mock the aggregate class
          aggregate_class = double('CompanyManagementUserSettingsAggregate')
          allow(aggregate_class).to receive(:respond_to?).with(:read_model_name).and_return(true)
          allow(aggregate_class).to receive(:read_model_name).and_return('company_management_user_settings')
          allow(aggregate_class).to receive(:respond_to?).with(:changes_read_model_name).and_return(false)
          
          allow(Object).to receive(:const_get).with('CompanyManagement::UserSettings::Aggregate').and_return(aggregate_class)
        end

        it 'preserves plurality in compound names' do
          class_names = configuration.all_read_model_class_names
          
          # Should preserve UserSettings as plural
          expect(class_names).to include('CompanyManagementUserSettings')
          expect(class_names).not_to include('CompanyManagementUserSetting')
        end
      end
    end

    describe '#all_read_models_with_aggregate_classes' do
      context 'with plural model names' do
        before do
          # Register a test aggregate
          configuration.register_aggregate_class(:test, :company_settings)
          
          # Mock the aggregate class
          aggregate_class = Class.new
          allow(aggregate_class).to receive(:respond_to?).with(:read_model_name).and_return(true)
          allow(aggregate_class).to receive(:read_model_name).and_return('company_settings')
          allow(aggregate_class).to receive(:respond_to?).with(:changes_read_model_name).and_return(false)
          
          # Mock the read model class
          read_model_class = Class.new
          
          allow(Object).to receive(:const_get).with('Test::CompanySettings::Aggregate').and_return(aggregate_class)
          allow(Object).to receive(:const_get).with('CompanySettings').and_return(read_model_class)
        end

        it 'correctly resolves plural read model classes' do
          mappings = configuration.all_read_models_with_aggregate_classes
          
          expect(mappings).not_to be_empty
          expect(mappings.first[:read_model_class]).to be_a(Class)
        end
      end
    end

    describe 'classify vs camelize behavior' do
      it 'demonstrates the difference between classify and camelize' do
        # Document the actual behavior difference
        expect('company_settings'.classify).to eq('CompanySetting')  # Singularizes
        expect('company_settings'.camelize).to eq('CompanySettings')  # Preserves plurality
        
        expect('test_users'.classify).to eq('TestUser')  # Singularizes
        expect('test_users'.camelize).to eq('TestUsers')  # Preserves plurality
        
        expect('user'.classify).to eq('User')  # Already singular
        expect('user'.camelize).to eq('User')  # Already singular
      end
    end
  end
end