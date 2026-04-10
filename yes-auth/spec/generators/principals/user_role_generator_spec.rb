# frozen_string_literal: true

require_relative '../generator_spec_helper'

RSpec.describe Yes::Auth::Generators::Principals::UserRoleGenerator do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:migrate_dir) { File.join(tmp_dir, 'db/migrate') }

  before { FileUtils.mkdir_p(migrate_dir) }
  after { FileUtils.rm_rf(tmp_dir) }

  describe '#create' do
    subject(:run_generator) do
      described_class.start([], destination_root: tmp_dir)
    end

    it 'creates a migration file' do
      run_generator

      migration_files = Dir[File.join(migrate_dir, '*_create_join_table_*.rb')]
      expect(migration_files.length).to eq(1)
    end

    it 'generates correct migration content' do
      run_generator

      migration_file = Dir[File.join(migrate_dir, '*.rb')].first
      content = File.read(migration_file)

      aggregate_failures do
        expect(content).to include('create_join_table')
        expect(content).to include('column_options: { type: :uuid, foreign_key: { on_delete: :cascade } }')
        expect(content).to include('Yes::Auth::Principals::User.find_each')
        expect(content).to include('Yes::Auth::Principals::Role.find_by')
      end
    end
  end
end
