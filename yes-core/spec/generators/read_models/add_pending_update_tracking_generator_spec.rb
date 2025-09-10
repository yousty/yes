# frozen_string_literal: true

RSpec.describe Yes::Core::Generators::ReadModels::AddPendingUpdateTrackingGenerator, type: :generator do
  let(:destination) { File.expand_path('../../../../dummy', __dir__) }

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
      # Only remove if it's a new file created during the test
      unless @existing_migrations.include?(basename)
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
      expect(migration_content).to include('class AddPendingUpdateTrackingToReadModels < ActiveRecord::Migration')
      expect(migration_content).to include('def up')
      expect(migration_content).to include('def down')
      expect(migration_content).to include('Yes::Core.configuration.all_read_model_table_names')
    end

    it 'defines helper methods for adding and removing tracking' do
      expect(migration_content).to include('def add_pending_tracking_to_table(table_name)')
      expect(migration_content).to include('def remove_pending_tracking_from_table(table_name)')
    end

    it 'adds pending_update_since column with proper checks' do
      expect(migration_content).to include('add_column table_name, :pending_update_since, :datetime')
      expect(migration_content).to include('unless column_exists?(table_name, :pending_update_since)')
    end

    it 'adds unique index for preventing concurrent updates' do
      expect(migration_content).to include('add_index table_name')
      expect(migration_content).to include('unique: true')
      expect(migration_content).to include("where: 'pending_update_since IS NOT NULL'")
      expect(migration_content).to include('idx_#{table_name}_one_pending_per_aggregate')
    end

    it 'adds recovery index for efficient querying' do
      expect(migration_content).to include('idx_#{table_name}_pending_recovery')
      expect(migration_content).to include(':pending_update_since')
      expect(migration_content).to include("where: 'pending_update_since IS NOT NULL'")
    end

    it 'handles both id and aggregate_id columns' do
      expect(migration_content).to include('aggregate_id_column = if column_exists?(table_name, :aggregate_id)')
      expect(migration_content).to include(':aggregate_id')
      expect(migration_content).to include(':id')
    end

    it 'removes columns and indexes in down method' do
      expect(migration_content).to include('remove_index table_name, name: index_name')
      expect(migration_content).to include('remove_index table_name, name: recovery_index_name')
      expect(migration_content).to include('remove_column table_name, :pending_update_since')
    end

    it 'checks table existence before processing' do
      expect(migration_content).to include('next unless ActiveRecord::Base.connection.table_exists?(table_name)')
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