# frozen_string_literal: true

module Yes
  module Auth
    module Principals
      # Represents a write resource access record linking a principal to a role-based write permission.
      #
      # @example Checking if an access is complete
      #   access = Yes::Auth::Principals::WriteResourceAccess.find(id)
      #   access.authorization_complete?
      class WriteResourceAccess < ActiveRecord::Base
        self.table_name = 'auth_principals_write_resource_accesses'

        belongs_to :role, class_name: 'Yes::Auth::Principals::Role', optional: true

        # @return [Boolean] whether all required fields are present for authorization
        def authorization_complete?
          context.present? && resource_type.present? && role.present? && resource_id.present?
        end
      end
    end
  end
end
