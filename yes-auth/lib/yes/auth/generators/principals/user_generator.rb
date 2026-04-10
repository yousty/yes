# frozen_string_literal: true

require_relative '../base_generator'

module Yes
  module Auth
    module Generators
      module Principals
        # Generates the migration for the user principals table
        #
        # @example
        #   rails generate yes:auth:principals:user
        class UserGenerator < BaseGenerator
          source_root File.expand_path('../templates', __dir__)

          namespace 'yes:auth:principals:user'
          desc 'Create migration for Yes::Auth::Principals::User'

          def _table_name
            Yes::Auth::Principals::User.table_name
          end

          def _source_template
            'user.erb'
          end
        end
      end
    end
  end
end
