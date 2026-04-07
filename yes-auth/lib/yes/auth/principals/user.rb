# frozen_string_literal: true

module Yes
  module Auth
    module Principals
      # Represents an authorization principal user with roles and resource accesses.
      #
      # @example Finding a user and checking roles
      #   user = Yes::Auth::Principals::User.find_by(identity_id: 'some-uuid')
      #   user.read_resource_access_authorization_roles
      class User < ActiveRecord::Base
        self.table_name = 'auth_principals_users'

        NO_AUTHORIZATION_ROLES_YET = ['no-roles-yet'].freeze

        has_and_belongs_to_many :roles, class_name: 'Yes::Auth::Principals::Role',
                                        foreign_key: :auth_principals_user_id,
                                        association_foreign_key: :auth_principals_role_id

        has_many :write_resource_accesses, class_name: 'Yes::Auth::Principals::WriteResourceAccess',
                                           foreign_key: :principal_id

        has_many :read_resource_accesses, class_name: 'Yes::Auth::Principals::ReadResourceAccess',
                                          foreign_key: :principal_id

        # @return [Array<String>] role names for read resource access authorization
        # NOTE: Runs 2 queries (resource access roles + direct roles). The direct roles
        # query is shared with write_resource_access_authorization_roles but cannot be
        # easily combined since they query different join tables. Use .includes(:roles)
        # when loading the User to avoid N+1 on the direct roles association.
        def read_resource_access_authorization_roles
          read_role_names = Set.new(
            Role.joins(:read_resource_accesses).where(read_resource_accesses: { principal_id: id }).complete.pluck(:name)
          )

          (read_role_names + complete_role_names).to_a
        end

        # @return [Array<String>] role names for write resource access authorization
        # NOTE: Runs 2 queries (resource access roles + direct roles). The direct roles
        # query is shared with read_resource_access_authorization_roles but cannot be
        # easily combined since they query different join tables. Use .includes(:roles)
        # when loading the User to avoid N+1 on the direct roles association.
        def write_resource_access_authorization_roles
          write_role_names = Set.new(
            Role.joins(:write_resource_accesses).where(write_resource_accesses: { principal_id: id }).complete.pluck(:name)
          )

          (write_role_names + complete_role_names).to_a
        end

        # @return [Boolean] whether the user has the super admin role
        def super_admin?
          super_admin_role_id = Role.super_admin_role&.id
          return false unless super_admin_role_id

          roles.ids.include?(super_admin_role_id)
        end

        private

        # @return [Array<String>] cached complete role names for the user
        def complete_role_names
          @complete_role_names ||= roles.complete.pluck(:name)
        end
      end
    end
  end
end
