# frozen_string_literal: true

require 'rails/generators'

module Yes
  module Core
    module Generators
      module ReadModels
        # Generator to add pending_update_since tracking to read models
        # Usage: rails generate yes:core:read_models:add_pending_update_tracking
        class AddPendingUpdateTrackingGenerator < Rails::Generators::Base
          include Rails::Generators::Migration

          source_root File.expand_path('templates', __dir__)

          # Generator description for help text
          desc 'Adds pending_update_since column and constraints to read models for consistency tracking'

          # Main generator method
          def create_migration
            migration_number = self.class.next_migration_number(File.join(destination_root, 'db/migrate'))
            path = File.join(destination_root, "db/migrate/#{migration_number}_add_pending_update_tracking_to_read_models.rb")
            template('add_pending_update_tracking.rb.erb', path)
          end

          # Required by Rails::Generators::Migration
          def self.next_migration_number(dirname)
            next_migration_number = current_migration_number(dirname) + 1
            ActiveRecord::Migration.next_migration_number(next_migration_number)
          end

          private

          # Returns the Rails migration version
          # @return [String] The migration version string
          def migration_version
            "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
          end
        end
      end
    end
  end
end