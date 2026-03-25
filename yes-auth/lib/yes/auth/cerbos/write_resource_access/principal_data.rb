# frozen_string_literal: true

module Yes
  module Auth
    module Cerbos
      module WriteResourceAccess
        # Builds principal data for Cerbos authorization based on write resource accesses.
        #
        # @example Building principal data
        #   Yes::Auth::Cerbos::WriteResourceAccess::PrincipalData.call(identity_id: 'user-uuid')
        #   # => { id: 'identity-id', roles: ['role1'], attributes: { ... } }
        class PrincipalData
          class << self
            # @param auth_data [Hash] authentication data containing :identity_id
            # @return [Hash] Cerbos-compatible principal data, or empty hash if principal not found
            def call(auth_data)
              return {} unless (principal = load_principal(auth_data[:identity_id]))

              write_resource_accesses = load_write_resource_accesses(principal.id)

              {
                id: principal.identity_id,
                roles: roles(principal),
                attributes: attributes(principal, write_resource_accesses)
              }.with_indifferent_access
            end

            private

            # @param principal_id [String] the principal's database ID
            # @return [ActiveRecord::Relation] write resource accesses with joined roles
            def load_write_resource_accesses(principal_id)
              Principals::WriteResourceAccess.joins(:role).where(principal_id:)
            end

            # @param identity_id [String] the identity ID to look up
            # @return [Yes::Auth::Principals::User, nil] the found principal or nil
            def load_principal(identity_id)
              Principals::User.find_by(identity_id:)
            end

            # @param principal [Yes::Auth::Principals::User] the principal user
            # @return [Array<String>] authorization roles or fallback roles
            def roles(principal)
              principal.write_resource_access_authorization_roles.presence || Principals::User::NO_AUTHORIZATION_ROLES_YET
            end

            # @param principal [Yes::Auth::Principals::User] the principal user
            # @param write_resource_accesses [ActiveRecord::Relation] the write resource accesses
            # @return [Hash] Cerbos principal attributes
            def attributes(principal, write_resource_accesses)
              PrincipalAttributes.call(principal:, write_resource_accesses:)
            end
          end
        end
      end
    end
  end
end
