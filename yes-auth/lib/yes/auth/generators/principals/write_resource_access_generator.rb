# frozen_string_literal: true

require_relative '../base_generator'

module Yes
  module Auth
    module Generators
      module Principals
        # Generates the migration for the write resource access principals table
        #
        # @example
        #   rails generate yes:auth:principals:write_resource_access
        class WriteResourceAccessGenerator < BaseGenerator
          source_root File.expand_path('../templates', __dir__)

          namespace 'yes:auth:principals:write_resource_access'
          desc 'Create migration for Yes::Auth::Principals::WriteResourceAccess'

          def _table_name
            Yes::Auth::Principals::WriteResourceAccess.table_name
          end

          def _source_template
            'write_resource_access.erb'
          end
        end
      end
    end
  end
end
