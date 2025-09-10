# frozen_string_literal: true

RSpec.describe Yes::Core::Generators::ReadModels::UpdateGenerator, type: :generator do
  let(:destination) { File.expand_path('../../../../dummy', __dir__) }

  before do
    self.destination_root = destination

    # Set Rails.root to the destination root
    allow(Rails).to receive(:root).and_return(Pathname.new(destination_root))
  end

  after do
    # Clean up generated migration files while preserving create_test_aggregates
    Dir[File.join(destination_root, 'db/migrate/*')].each do |file|
      if file.include?('create_test_users') ||
         file.include?('create_test_locations') ||
         file.include?('create_shared_profile_read_model') ||
         file.include?('add_pending_update_tracking')
        next
      end

      FileUtils.rm_f(file)
    end
  end

  describe '#create_migration' do
    subject(:migration_content) do
      run_generator
      migration_file = Dir[File.join(destination_root, 'db/migrate/*_update_read_models.rb')].first

      File.read(migration_file)
    end

    context 'for existing users table' do
      before do
        Test::User::Aggregate.attribute :something, :string
      end

      after do
        Test::User::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                    Test::User::Aggregate.attributes.except(:something))
      end

      it 'adds missing column from aggregate' do
        expect(migration_content).to include('add_column :test_users, :something, :string')
      end

      it 'removes extra columns from database' do
        aggregate_failures do
          expect(migration_content).to include('remove_column :test_users, :test_field')
          expect(migration_content).to include('remove_column :test_users, :location_id')
        end
      end

      it 'does not recreate existing columns' do
        aggregate_failures do
          expect(migration_content).not_to include('create_table :test_users')
          expect(migration_content).not_to include('t.string :name')
          expect(migration_content).not_to include('t.string :email')
          expect(migration_content).not_to include('t.integer :age')
          expect(migration_content).not_to include('t.boolean :active')
        end
      end

      context 'when revision column does not exist' do
        let(:existing_columns) do
          %w[id created_at updated_at name email age active test_field location_id]
        end

        before do
          allow(ActiveRecord::Base.connection).to receive(:columns).and_return(
            existing_columns.map { |name| double(name: name) }
          )
        end

        it 'adds revision column' do
          expect(migration_content).to include('add_column :test_users, :revision, :integer, null: false, default: -1')
        end
      end

      context 'when revision column exists' do
        let(:existing_columns) do
          %w[id created_at updated_at name email age active test_field location_id revision]
        end

        before do
          allow(ActiveRecord::Base.connection).to receive(:columns).and_return(
            existing_columns.map { |name| double(name: name) }
          )
        end

        it 'does not add revision column again' do
          expect(migration_content).not_to include('add_column :test_users, :revision')
        end

        it 'never removes the revision column' do
          aggregate_failures do
            expect(migration_content).to include('remove_column :test_users, :test_field')
            expect(migration_content).to include('remove_column :test_users, :location_id')
            expect(migration_content).not_to include('remove_column :test_users, :revision')
          end
        end
      end
    end

    context 'for non-existing stars table' do
      it 'creates new table with all columns' do
        aggregate_failures do
          expect(migration_content).to include('create_table :universe_stars')
          expect(migration_content).to include('t.string :label')
          expect(migration_content).to include('t.integer :size')
          expect(migration_content).to include('t.timestamps')
        end
      end

      it 'includes revision column' do
        expect(migration_content).to include('t.integer :revision, null: false, default: -1')
      end

      context 'with aggregate type attribute' do
        before do
          Universe::Star::Aggregate.attribute :galaxy, :aggregate
        end

        after do
          Universe::Star::Aggregate.singleton_class.instance_variable_set(:@attributes,
                                                                          Universe::Star::Aggregate.attributes.except(:galaxy))
        end

        it 'creates table with _id column for aggregate attribute' do
          expect(migration_content).to include('t.uuid :galaxy_id')
        end

        it 'does not create column without _id suffix' do
          expect(migration_content).not_to include('t.string :galaxy')
        end
      end
    end
  end

  describe '#build_remove_column_statements' do
    subject(:generator) do
      described_class.new.send(:build_remove_column_statements, table_name, existing_columns, defined_columns)
    end
    let(:existing_columns) { %w[name email age active test_field location_id revision] }
    let(:defined_columns) { %w[name email age active] }
    let(:table_name) { 'test_users' }

    it 'excludes revision column from removal' do
      statements = subject

      aggregate_failures do
        expect(statements).to include('remove_column :test_users, :test_field')
        expect(statements).to include('remove_column :test_users, :location_id')
        expect(statements).not_to include('remove_column :test_users, :revision')
      end
    end
  end
end
