# frozen_string_literal: true

module Yes
  module Auth
    module Principals
      # Represents an authorization role that can be assigned to users and resource accesses.
      #
      # @example Finding the super admin role
      #   Yes::Auth::Principals::Role.super_admin_role
      class Role < ApplicationRecord
        self.table_name = 'auth_principals_roles'

        SUPER_ADMIN_ROLE_NAME = 'admin'

        has_and_belongs_to_many :users, class_name: 'Yes::Auth::Principals::User',
                                        foreign_key: :auth_principals_role_id,
                                        association_foreign_key: :auth_principals_user_id

        has_many :read_resource_accesses, class_name: 'Yes::Auth::Principals::ReadResourceAccess'
        has_many :write_resource_accesses, class_name: 'Yes::Auth::Principals::WriteResourceAccess'

        scope :complete, -> { where.not(name: nil) }

        # @return [String, nil] the role name with colons replaced by underscores
        def resource_authorization_name
          name&.tr(':', '_')
        end

        # @return [Yes::Auth::Principals::Role, nil] the super admin role
        def self.super_admin_role
          find_by(name: SUPER_ADMIN_ROLE_NAME)
        end
      end
    end
  end
end
