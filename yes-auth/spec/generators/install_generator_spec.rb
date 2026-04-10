# frozen_string_literal: true

require_relative 'generator_spec_helper'

RSpec.describe Yes::Auth::Generators::InstallGenerator do
  let(:tmp_dir) { Dir.mktmpdir }
  let(:migrate_dir) { File.join(tmp_dir, 'db/migrate') }

  before { FileUtils.mkdir_p(migrate_dir) }
  after { FileUtils.rm_rf(tmp_dir) }

  describe '#run_generators' do
    subject(:run_generator) do
      described_class.start([], destination_root: tmp_dir)
    end

    it 'creates migrations for all 5 principal tables' do
      run_generator

      migration_files = Dir[File.join(migrate_dir, '*.rb')]

      aggregate_failures do
        expect(migration_files.length).to eq(5)
        expect(migration_files.any? { |f| f.include?('read_resource_access') }).to be true
        expect(migration_files.any? { |f| f.include?('write_resource_access') }).to be true
        expect(migration_files.any? { |f| f.include?('auth_principals_role') }).to be true
        expect(migration_files.any? { |f| f.include?('auth_principals_user') }).to be true
        expect(migration_files.any? { |f| f.include?('join_table') }).to be true
      end
    end
  end
end
