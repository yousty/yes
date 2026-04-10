# frozen_string_literal: true

require_relative '../base_generator'

module Yes
  module Auth
    module Generators
      module Principals
        # Generates the migration for the user-role join table
        #
        # This generator creates a join table for the HABTM association between
        # User and Role principals, with UUID foreign keys and cascade deletes.
        #
        # @example
        #   rails generate yes:auth:principals:user_role
        class UserRoleGenerator < BaseGenerator
          source_root File.expand_path('../templates', __dir__)

          namespace 'yes:auth:principals:user_role'
          desc 'Create migration for the User-Role join table'

          def _table_name
            "#{Yes::Auth::Principals::User.reflect_on_association(:roles).table_name}_" \
              "#{Yes::Auth::Principals::Role.reflect_on_association(:users).plural_name}"
          end

          def _migration_file_name
            "create_join_table_#{_user_table_name.singularize}_#{_role_table_name.singularize}.rb"
          end

          def _user_table_name
            Yes::Auth::Principals::User.table_name
          end

          def _role_table_name
            Yes::Auth::Principals::Role.table_name
          end

          def _user_primary_key
            Yes::Auth::Principals::Role.reflect_on_association(:users).foreign_key
          end

          def _role_primary_key
            Yes::Auth::Principals::User.reflect_on_association(:roles).foreign_key
          end

          def _source_template
            'user_role.erb'
          end
        end
      end
    end
  end
end
