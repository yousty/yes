# frozen_string_literal: true

require 'rails/generators'

module Yes
  module Auth
    module Generators
      # Base class for auth principal migration generators
      #
      # Provides shared migration generation logic including timestamp calculation,
      # existence checking, and template rendering.
      #
      # @abstract Subclass and implement {#_table_name} and {#_source_template}
      class BaseGenerator < Rails::Generators::Base
        include ::Rails::Generators::Migration

        hide!

        # Calculates the next migration number based on existing migrations
        #
        # @param migrations_root [String] path to the migrations directory
        # @return [String] the next migration number as a timestamp string
        def self.next_migration_number(migrations_root)
          paths = Dir["#{migrations_root}/*.rb"].map do |path|
            File.basename(path)
          end
          timestamps = paths.map { |name| name.split('_').first }
          latest = timestamps.max || '0'
          [Time.now.utc.strftime('%Y%m%d%H%M%S'), format('%.14d', latest.next)].max
        end

        def create
          raise "Migration already exists in #{_migration_dir}" if self.class.migration_exists?(_migration_dir, _migration_file_name)

          migration_template(_source_template, _destination)
        end

        def _table_name
          raise NotImplementedError
        end

        def _source_template
          raise NotImplementedError
        end

        def _destination
          "#{_migration_dir}/#{_migration_file_name}"
        end

        def _migration_file_name
          "create_#{_table_name.singularize}.rb"
        end

        def _migration_dir
          'db/migrate'
        end
      end
    end
  end
end
