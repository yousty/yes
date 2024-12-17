# frozen_string_literal: true

module Yes
  module ReadModels
    class UpdateGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path('templates', __dir__)

      desc 'Creates or updates read models for aggregates'

      def create_migration
        @aggregates = find_aggregates
        return if @aggregates.empty?

        migration_number = self.class.next_migration_number(File.join(destination_root, 'db/migrate'))
        template(
          'migration.rb.erb',
          File.join(destination_root, "db/migrate/#{migration_number}_update_read_models.rb")
        )
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
        table_name = aggregate[:aggregate].underscore.pluralize
        
        if !table_exists?(table_name)
          create_table_block(aggregate)
        else
          alter_table_block(aggregate, table_name)
        end
      end

      def create_table_block(aggregate)
        table_name = aggregate[:aggregate].underscore.pluralize
        <<~RUBY
          create_table :#{table_name} do |t|
            #{column_definitions(aggregate[:attributes])}
            t.timestamps
          end
        RUBY
      end

      def alter_table_block(aggregate, table_name)
        existing_columns = ActiveRecord::Base.connection.columns(table_name).map(&:name) - %w[id created_at updated_at]
        defined_columns = aggregate[:attributes].keys.map(&:to_s)
        
        columns_to_add = defined_columns - existing_columns
        columns_to_remove = existing_columns - defined_columns
        
        statements = []
        
        columns_to_add.each do |column|
          type = aggregate[:attributes][column.to_sym]
          statements << "add_column :#{table_name}, :#{column}, :#{database_type(type)}"
        end
        
        columns_to_remove.each do |column|
          statements << "remove_column :#{table_name}, :#{column}"
        end
        
        statements.join("\n    ")
      end

      def column_definitions(attributes)
        attributes.map do |name, type|
          "t.#{database_type(type)} :#{name}"
        end.join("\n      ")
      end

      def table_exists?(table_name)
        ActiveRecord::Base.connection.table_exists?(table_name)
      end

      def database_type(type)
        case type
        when :string, :email, :url then :string
        when :integer then :integer
        when :uuid then :uuid
        when :boolean then :boolean
        when :float then :float
        when :datetime then :datetime
        when :hash then :jsonb
        else :string # default to string for unknown types
        end
      end
    end
  end
end
