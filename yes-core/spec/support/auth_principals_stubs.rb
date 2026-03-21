# frozen_string_literal: true

# Stub constants for Yes::Core::Auth::Principals used in tests.
module Yes
  module Core
    module Auth
      module Principals
        # Stub for role constants
        module Role
          SUPER_ADMIN_ROLE_NAME = 'super_admin'
        end

        # Stub for user constants
        module User
          NO_AUTHORIZATION_ROLES_YET = %w[no_authorization_roles_yet].freeze
        end
      end
    end
  end
end
