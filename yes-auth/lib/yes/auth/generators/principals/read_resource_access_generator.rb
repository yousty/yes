# frozen_string_literal: true

require_relative '../base_generator'

module Yes
  module Auth
    module Generators
      module Principals
        # Generates the migration for the read resource access principals table
        #
        # @example
        #   rails generate yes:auth:principals:read_resource_access
        class ReadResourceAccessGenerator < BaseGenerator
          source_root File.expand_path('../templates', __dir__)

          namespace 'yes:auth:principals:read_resource_access'
          desc 'Create migration for Yes::Auth::Principals::ReadResourceAccess'

          def _table_name
            Yes::Auth::Principals::ReadResourceAccess.table_name
          end

          def _source_template
            'read_resource_access.erb'
          end
        end
      end
    end
  end
end
