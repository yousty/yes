# frozen_string_literal: true

module Yes
  module Auth
    module Principals
      # Represents a read resource access record linking a principal to a role-based read permission.
      #
      # @example Checking if an access is complete
      #   access = Yes::Auth::Principals::ReadResourceAccess.find(id)
      #   access.authorization_complete?
      class ReadResourceAccess < ActiveRecord::Base
        self.table_name = 'auth_principals_read_resource_accesses'

        belongs_to :role, class_name: 'Yes::Auth::Principals::Role', optional: true

        # @return [Boolean] whether all required fields are present for authorization
        def authorization_complete?
          service.present? && scope.present? && resource_type.present? && role.present? && resource_id.present?
        end
      end
    end
  end
end
