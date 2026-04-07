# frozen_string_literal: true

module Yes
  module Auth
    module Cerbos
      module WriteResourceAccess
        # Builds principal attributes for Cerbos authorization based on write resource accesses.
        #
        # @example Building attributes
        #   Yes::Auth::Cerbos::WriteResourceAccess::PrincipalAttributes.call(
        #     principal: user,
        #     write_resource_accesses: accesses
        #   )
        class PrincipalAttributes
          class << self
            # @param principal [Yes::Auth::Principals::User, nil] the principal user
            # @param write_resource_accesses [Array, ActiveRecord::Relation] write resource accesses
            # @return [HashWithIndifferentAccess] Cerbos principal attributes
            def call(principal: nil, write_resource_accesses: [])
              return {} unless principal

              {
                **(principal.auth_attributes || {}),
                write_resource_access: write_attributes(write_resource_accesses)
              }.with_indifferent_access
            end

            private

            # @param accesses [Array, ActiveRecord::Relation] write resource accesses
            # @return [Hash] nested hash of write resource access attributes
            def write_attributes(accesses)
              attributes = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

              accesses.each do |access|
                next unless access.authorization_complete?

                attributes[access.context][access.resource_type][access.role&.resource_authorization_name][access.resource_id] =
                  access.auth_attributes || {}
              end

              attributes
            end
          end
        end
      end
    end
  end
end
