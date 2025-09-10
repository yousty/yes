# frozen_string_literal: true

require 'rails/generators'
require 'rails/generators/active_record'

module Yes
  module Core
    module Generators
      module ReadModels
        # Generator to add pending_update_since tracking to read models
        # Usage: rails generate yes:core:read_models:add_pending_update_tracking
        class AddPendingUpdateTrackingGenerator < Rails::Generators::Base
          include ActiveRecord::Generators::Migration

          source_root File.expand_path('templates', __dir__)

          # Generator description for help text
          desc 'Adds pending_update_since column and constraints to read models for consistency tracking'

          # Main generator method
          def create_migration
            migration_template(
              'add_pending_update_tracking.rb.erb',
              "db/migrate/add_pending_update_tracking_to_read_models.rb",
              migration_version: migration_version
            )
          end

          private

          # Returns the Rails migration version
          # @return [String] The migration version string
          def migration_version
            "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
          end

          # Returns the current timestamp for migration file naming
          # @return [String] Timestamp string
          def self.next_migration_number(dirname)
            ActiveRecord::Generators::Base.next_migration_number(dirname)
          end
        end
      end
    end
  end
end