# frozen_string_literal: true

module Yes
  module Auth
    module Generators
      # Generates all auth principal migrations at once
      #
      # @example
      #   rails generate yes:auth:install
      class InstallGenerator < Rails::Generators::Base
        namespace 'yes:auth:install'
        desc 'Create all migrations for Yes::Auth principals'

        def run_generators
          invoke 'yes:auth:principals:read_resource_access'
          invoke 'yes:auth:principals:write_resource_access'
          invoke 'yes:auth:principals:role'
          invoke 'yes:auth:principals:user'
          invoke 'yes:auth:principals:user_role'
        end
      end
    end
  end
end
