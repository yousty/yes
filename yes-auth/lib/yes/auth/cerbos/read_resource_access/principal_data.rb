# frozen_string_literal: true

module Yes
  module Auth
    module Cerbos
      module ReadResourceAccess
        # Builds principal data for Cerbos authorization based on read resource accesses.
        #
        # @example Building principal data
        #   Yes::Auth::Cerbos::ReadResourceAccess::PrincipalData.call(identity_id: 'user-uuid')
        #   # => { id: 'identity-id', roles: ['role1'], attributes: { ... } }
        class PrincipalData
          class << self
            # @param auth_data [Hash] authentication data containing :identity_id
            # @return [Hash] Cerbos-compatible principal data, or empty hash if principal not found
            def call(auth_data)
              return {} unless (principal = load_principal(auth_data[:identity_id]))

              read_resource_accesses = load_read_resource_accesses(principal.id)

              {
                id: principal.identity_id,
                roles: roles(principal),
                attributes: attributes(principal, read_resource_accesses)
              }.with_indifferent_access
            end

            private

            # @param principal_id [String] the principal's database ID
            # @return [ActiveRecord::Relation] read resource accesses with joined roles
            def load_read_resource_accesses(principal_id)
              Principals::ReadResourceAccess.eager_load(:role).where(principal_id:)
            end

            # @param identity_id [String] the identity ID to look up
            # @return [Yes::Auth::Principals::User, nil] the found principal or nil
            def load_principal(identity_id)
              Principals::User.includes(:roles).find_by(identity_id:)
            end

            # @param principal [Yes::Auth::Principals::User] the principal user
            # @return [Array<String>] authorization roles or fallback roles
            def roles(principal)
              principal.read_resource_access_authorization_roles.presence || Principals::User::NO_AUTHORIZATION_ROLES_YET
            end

            # @param principal [Yes::Auth::Principals::User] the principal user
            # @param read_resource_accesses [ActiveRecord::Relation] the read resource accesses
            # @return [Hash] Cerbos principal attributes
            def attributes(principal, read_resource_accesses)
              PrincipalAttributes.call(principal:, read_resource_accesses:)
            end
          end
        end
      end
    end
  end
end
