# frozen_string_literal: true

require 'rails/generators'

module Yes
  module Core
    module Generators
      module ReadModels
        class UpdateGenerator < Rails::Generators::Base
          include Rails::Generators::Migration

          source_root File.expand_path('templates', __dir__)

          desc 'Creates or updates read models for aggregates'

          def create_migration
            @aggregates = find_aggregates
            return if @aggregates.empty?

            migration_number = self.class.next_migration_number(File.join(destination_root, 'db/migrate'))

            path = File.join(destination_root, "db/migrate/#{migration_number}_update_read_models.rb")
            template('migration.rb.erb', path)
          end

          # Required by Rails::Generators::Migration
          def self.next_migration_number(dirname)
            next_migration_number = current_migration_number(dirname) + 1
            ActiveRecord::Migration.next_migration_number(next_migration_number)
          end

          private

          def find_aggregates
            root_path = Rails.root || Pathname.new(destination_root)

            Dir.glob(root_path.join('app/contexts/**/**/aggregate.rb')).map do |file|
              require file
              context, aggregate = file.split('contexts/').last.split('/')
              klass = "#{context.camelize}::#{aggregate.camelize}::Aggregate".constantize
              {
                context:,
                aggregate:,
                klass:,
                attributes: klass.attributes,
                read_model_name: klass.read_model_name
              }
            end
          end

          def table_operations(aggregate)
            table_name = aggregate[:read_model_name].to_s.pluralize

            if table_exists?(table_name)
              alter_table_block(aggregate, table_name)
            else
              create_table_block(aggregate)
            end
          end

          def create_table_block(aggregate)
            table_name = aggregate[:read_model_name].to_s.pluralize
            <<~RUBY
              create_table :#{table_name} do |t|
                #{column_definitions(aggregate[:attributes])}
                t.integer :revision, null: false, default: -1
                t.timestamps
              end
            RUBY
          end

          def alter_table_block(aggregate, table_name)
            existing_columns = fetch_existing_columns(table_name)
            defined_columns = build_defined_columns(aggregate)

            build_alter_statements(table_name, existing_columns, defined_columns, aggregate[:attributes])
          end

          def fetch_existing_columns(table_name)
            ActiveRecord::Base.connection.columns(table_name).map(&:name) - %w[id created_at updated_at]
          end

          def build_defined_columns(aggregate)
            aggregate[:attributes].keys.map do |key|
              type = aggregate[:attributes][key]
              type == :aggregate ? "#{key}_id" : key.to_s
            end
          end

          def build_alter_statements(table_name, existing_columns, defined_columns, attributes)
            statements = []
            statements << add_revision_statement(table_name) unless existing_columns.include?('revision')
            statements.concat(build_add_column_statements(table_name, existing_columns, defined_columns, attributes))
            statements.concat(build_remove_column_statements(table_name, existing_columns, defined_columns))
            statements.join("\n    ")
          end

          def add_revision_statement(table_name)
            "add_column :#{table_name}, :revision, :integer, null: false, default: -1"
          end

          def build_add_column_statements(table_name, existing_columns, defined_columns, attributes)
            (defined_columns - existing_columns).map do |column|
              attribute_name = column.end_with?('_id') ? column.chomp('_id').to_sym : column.to_sym
              type = attributes[attribute_name]
              "add_column :#{table_name}, :#{column}, :#{database_type(type)}"
            end
          end

          def build_remove_column_statements(table_name, existing_columns, defined_columns)
            (existing_columns - defined_columns - ['revision']).map do |column|
              "remove_column :#{table_name}, :#{column}"
            end
          end

          def column_definitions(attributes)
            attributes.map do |name, type|
              if type == :aggregate
                "t.uuid :#{name}_id"
              else
                "t.#{database_type(type)} :#{name}"
              end
            end.join("\n      ")
          end

          def table_exists?(table_name)
            ActiveRecord::Base.connection.table_exists?(table_name)
          end

          def database_type(type) # rubocop:disable Metrics/CyclomaticComplexity
            case type
            when :string, :email, :url then :string
            when :integer then :integer
            when :uuid then :uuid
            when :boolean then :boolean
            when :float then :float
            when :datetime then :datetime
            when :hash then :jsonb
            when :aggregate then :uuid
            else :string # default to string for unknown types
            end
          end
        end
      end
    end
  end
end
