# frozen_string_literal: true

require_relative '../generator_spec_helper'

RSpec.describe Yes::Auth::Generators::Principals::RoleGenerator do
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

      migration_files = Dir[File.join(migrate_dir, '*_create_auth_principals_role.rb')]
      expect(migration_files.length).to eq(1)
    end

    it 'generates correct migration content' do
      run_generator

      migration_file = Dir[File.join(migrate_dir, '*.rb')].first
      content = File.read(migration_file)

      aggregate_failures do
        expect(content).to include('create_table :auth_principals_roles, id: :uuid')
        expect(content).to include('t.string :name')
        expect(content).to include('add_index :auth_principals_roles, :name, unique: true')
      end
    end
  end
end
