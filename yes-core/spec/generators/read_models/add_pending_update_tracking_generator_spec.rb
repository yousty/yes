# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

RSpec.describe Yes::Core::Generators::ReadModels::AddPendingUpdateTrackingGenerator, type: :generator do
  let(:destination) { Dir.mktmpdir('generator_test') }

  before do
    self.destination_root = destination

    # Set Rails.root to the destination root
    allow(Rails).to receive(:root).and_return(Pathname.new(destination_root))
    
    # Create the migration directory
    FileUtils.mkdir_p(File.join(destination_root, 'db/migrate'))
  end

  after do
    # Clean up the temporary directory
    FileUtils.rm_rf(destination) if File.exist?(destination)
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

    it 'includes say statements for feedback' do
      expect(migration_content).to include('say "Added pending_update_since column')
      expect(migration_content).to include('say "Added unique partial index')
      expect(migration_content).to include('say "Added recovery index')
      expect(migration_content).to include('say "Removed pending tracking')
    end

    it 'truncates long index names correctly' do
      expect(migration_content).to include('def truncate_index_name(name)')
      expect(migration_content).to include('return name if name.length <= 62')
      expect(migration_content).to include('Digest::SHA256.hexdigest(name)[0..7]')
      expect(migration_content).to include('truncate_index_name("idx_#{table_name}_one_pending_per_aggregate")')
      expect(migration_content).to include('truncate_index_name("idx_#{table_name}_pending_recovery")')
    end

    it 'handles very long table names by truncating index names' do
      # The logic in the migration will truncate names over 62 chars
      # Test that the helper method is defined
      expect(migration_content).to include('def truncate_index_name')
      
      # Test that it's used for both index types
      expect(migration_content).to match(/index_name = truncate_index_name\("idx_#\{table_name\}_one_pending_per_aggregate"\)/)
      expect(migration_content).to match(/recovery_index_name = truncate_index_name\("idx_#\{table_name\}_pending_recovery"\)/)
    end
  end

  describe '.next_migration_number' do
    it 'generates sequential migration numbers' do
      # Create a dummy migration to set the baseline
      FileUtils.touch(File.join(destination_root, 'db/migrate/20240101000000_dummy_migration.rb'))
      
      next_number = described_class.next_migration_number(File.join(destination_root, 'db/migrate'))
      expect(next_number).to be > '20240101000000'
      expect(next_number).to match(/^\d{14}$/)
    end
  end
end