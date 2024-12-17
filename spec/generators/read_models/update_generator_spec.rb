# frozen_string_literal: true

require 'spec_helper'
require 'generators/yes/read_models/update_generator'

RSpec.describe Yes::ReadModels::UpdateGenerator, type: :generator do
  let(:destination) { File.expand_path('../../../dummy', __dir__) }

  before do
    self.destination_root = destination

    # Set Rails.root to the destination root
    allow(Rails).to receive(:root).and_return(Pathname.new(destination_root))
  end

  after do
    # Clean up generated migration files while preserving create_test_aggregates
    Dir[File.join(destination_root, 'db/migrate/*')].each do |file|
      next if file.include?('create_users')
      FileUtils.rm_f(file)
    end
  end

  describe '#create_migration' do
    subject(:migration_content) do
      run_generator
      migration_file = Dir[File.join(destination_root, 'db/migrate/*_update_read_models.rb')].first
      File.read(migration_file)
    end

    it 'creates migration file with correct table operations' do
      expect(migration_content).to include('# Create or update read model for aggregate Test::User')
      expect(migration_content).to include('# Create or update read model for aggregate Universe::Star')
    end

    context 'for existing users table' do
      it 'adds missing column from aggregate' do
        expect(migration_content).to include('add_column :users, :something, :string')
      end

      it 'removes extra column from database' do
        expect(migration_content).to include('remove_column :users, :test_field')
      end

      it 'does not recreate existing columns' do
        expect(migration_content).not_to include('create_table :users')
        expect(migration_content).not_to include('t.string :name')
        expect(migration_content).not_to include('t.string :email')
        expect(migration_content).not_to include('t.integer :age')
        expect(migration_content).not_to include('t.boolean :active')
      end
    end

    context 'for non-existing stars table' do
      it 'creates new table with all columns' do
        expect(migration_content).to include('create_table :stars')
        expect(migration_content).to include('t.string :label')
        expect(migration_content).to include('t.integer :size')
        expect(migration_content).to include('t.timestamps')
      end
    end
  end
end
