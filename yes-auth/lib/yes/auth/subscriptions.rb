# frozen_string_literal: true

module Yes
  module Auth
    # Wires authorization event builders to the appropriate subscriptions.
    #
    # Role, User, WriteResourceAccess, and ReadResourceAccess builders
    # are registered via the yes-core ReadModel::Builder pattern.
    class Subscriptions
      # @param subscriptions [Object] the subscription registry
      # @return [void]
      def self.call(subscriptions)
        subscriptions.subscribe_to_all(
          Yes::Auth::ReadModels::Principals::Role::Builder.new,
          { event_types: ['Authorization::RoleNameChanged'] }
        )

        subscriptions.subscribe_to_all(
          Yes::Auth::ReadModels::Principals::User::Builder.new,
          { event_types: [
            'Authorization::PrincipalRoleAdded',
            'Authorization::PrincipalRoleRemoved',
            'Authorization::PrincipalAttributeChanged',
            'Authorization::PrincipalIdentityAssigned',
            'Authorization::PrincipalRemoved'
          ] }
        )

        subscriptions.subscribe_to_all(
          Yes::Auth::ReadModels::Principals::WriteResourceAccess::Builder.new,
          { event_types: [
            'Authorization::WriteResourceAccessAttributeChanged',
            'Authorization::WriteResourceAccessContextChanged',
            'Authorization::WriteResourceAccessPrincipalAssigned',
            'Authorization::WriteResourceAccessRemoved',
            'Authorization::WriteResourceAccessResourceAssigned',
            'Authorization::WriteResourceAccessResourceTypeChanged',
            'Authorization::WriteResourceAccessRoleChanged'
          ] }
        )

        subscriptions.subscribe_to_all(
          Yes::Auth::ReadModels::Principals::ReadResourceAccess::Builder.new,
          { event_types: [
            'Authorization::ReadResourceAccessPrincipalAssigned',
            'Authorization::ReadResourceAccessResourceTypeChanged',
            'Authorization::ReadResourceAccessRemoved',
            'Authorization::ReadResourceAccessResourceAssigned',
            'Authorization::ReadResourceAccessRoleChanged',
            'Authorization::ReadResourceAccessScopeChanged',
            'Authorization::ReadResourceAccessServiceChanged'
          ] }
        )
      end
    end
  end
end
