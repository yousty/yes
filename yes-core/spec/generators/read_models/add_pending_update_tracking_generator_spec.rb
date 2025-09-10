# frozen_string_literal: true

RSpec.describe Yes::Core::Generators::ReadModels::AddPendingUpdateTrackingGenerator, type: :generator do
  let(:destination) { File.expand_path('../../../../dummy', __dir__) }
  let(:existing_migration) { '20250101000000_add_pending_update_tracking_to_read_models.rb' }

  before do
    self.destination_root = destination

    # Set Rails.root to the destination root
    allow(Rails).to receive(:root).and_return(Pathname.new(destination_root))
    
    # Store list of existing migrations before running generator
    @existing_migrations = Dir[File.join(destination_root, 'db/migrate/*')].map { |f| File.basename(f) }
  end

  after do
    # Clean up only newly generated migration files, not existing ones
    Dir[File.join(destination_root, 'db/migrate/*')].each do |file|
      basename = File.basename(file)
      # Only remove if it's a new file created during the test and matches our pattern
      if basename.include?('add_pending_update_tracking_to_read_models') && 
         !@existing_migrations.include?(basename) &&
         basename != existing_migration
        FileUtils.rm_f(file)
      end
    end
  end

  describe '#create_migration' do
    subject(:migration_content) do
      run_generator
      migration_file = Dir[File.join(destination_root, 'db/migrate/*_add_pending_update_tracking_to_read_models.rb')].first
      File.read(migration_file) if migration_file
    end

    it 'creates a migration file with the correct name' do
      run_generator

      migration_file = Dir[File.join(destination_root, 'db/migrate/*_add_pending_update_tracking_to_read_models.rb')].first
      expect(migration_file).not_to be_nil
      expect(File.basename(migration_file)).to match(/\d+_add_pending_update_tracking_to_read_models\.rb/)
    end

    it 'generates migration with correct structure' do
      # Mock the configuration to return test read model classes
      allow(Yes::Core::Configuration).to receive(:all_read_model_table_names).and_return([
        'test_user_read_models',
        'shared_profile_read_models'
      ])

      expect(migration_content).to include('class AddPendingUpdateTrackingToReadModels < ActiveRecord::Migration')
      expect(migration_content).to include('def up')
      expect(migration_content).to include('def down')
    end

    it 'adds pending_update_since column to each read model table' do
      allow(Yes::Core::Configuration).to receive(:all_read_model_table_names).and_return([
        'test_user_read_models',
        'shared_profile_read_models'
      ])

      expect(migration_content).to include('add_column :test_user_read_models, :pending_update_since, :datetime')
      expect(migration_content).to include('add_column :shared_profile_read_models, :pending_update_since, :datetime')
    end

    it 'adds unique index for pending updates' do
      allow(Yes::Core::Configuration).to receive(:all_read_model_table_names).and_return([
        'test_user_read_models'
      ])

      expect(migration_content).to include('add_index :test_user_read_models')
      expect(migration_content).to include('unique: true')
      expect(migration_content).to include('where: "(pending_update_since IS NOT NULL)"')
      expect(migration_content).to include('name: "idx_test_user_read_models_one_pending_per_aggregate"')
    end

    it 'adds recovery index for efficient querying' do
      allow(Yes::Core::Configuration).to receive(:all_read_model_table_names).and_return([
        'test_user_read_models'
      ])

      expect(migration_content).to include('name: "idx_test_user_read_models_pending_recovery"')
      expect(migration_content).to include('where: "(pending_update_since IS NOT NULL)"')
    end

    it 'removes columns and indexes in down method' do
      allow(Yes::Core::Configuration).to receive(:all_read_model_table_names).and_return([
        'test_user_read_models'
      ])

      expect(migration_content).to include('remove_index :test_user_read_models, name: "idx_test_user_read_models_one_pending_per_aggregate"')
      expect(migration_content).to include('remove_index :test_user_read_models, name: "idx_test_user_read_models_pending_recovery"')
      expect(migration_content).to include('remove_column :test_user_read_models, :pending_update_since')
    end

    it 'handles empty read model list gracefully' do
      allow(Yes::Core::Configuration).to receive(:all_read_model_table_names).and_return([])

      expect(migration_content).to include('class AddPendingUpdateTrackingToReadModels < ActiveRecord::Migration')
      expect(migration_content).not_to include('add_column')
      expect(migration_content).not_to include('add_index')
    end

    it 'truncates long table names for index names' do
      allow(Yes::Core::Configuration).to receive(:all_read_model_table_names).and_return([
        'very_long_table_name_that_exceeds_normal_limits_for_index_naming_conventions'
      ])

      # PostgreSQL has a 63 character limit for index names
      expect(migration_content).to include('name: "idx_very_long_table_name_that_exceeds_norm_one_pending"')
      expect(migration_content).to include('name: "idx_very_long_table_name_that_exceeds_norm_pending_rec"')
    end
  end

  describe '.next_migration_number' do
    it 'generates sequential migration numbers' do
      # Create a dummy migration to set the baseline
      FileUtils.mkdir_p(File.join(destination_root, 'db/migrate'))
      FileUtils.touch(File.join(destination_root, 'db/migrate/20240101000000_dummy_migration.rb'))
      
      next_number = described_class.next_migration_number(File.join(destination_root, 'db/migrate'))
      expect(next_number).to be > '20240101000000'
      expect(next_number).to match(/^\d{14}$/)
    end
  end
end