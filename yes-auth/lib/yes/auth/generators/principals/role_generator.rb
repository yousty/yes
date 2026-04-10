# frozen_string_literal: true

require_relative '../base_generator'

module Yes
  module Auth
    module Generators
      module Principals
        # Generates the migration for the roles principals table
        #
        # @example
        #   rails generate yes:auth:principals:role
        class RoleGenerator < BaseGenerator
          source_root File.expand_path('../templates', __dir__)

          namespace 'yes:auth:principals:role'
          desc 'Create migration for Yes::Auth::Principals::Role'

          def _table_name
            Yes::Auth::Principals::Role.table_name
          end

          def _source_template
            'role.erb'
          end
        end
      end
    end
  end
end
