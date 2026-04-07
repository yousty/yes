# frozen_string_literal: true

module Yes
  module Auth
    module Cerbos
      module ReadResourceAccess
        # Builds principal attributes for Cerbos authorization based on read resource accesses.
        #
        # @example Building attributes
        #   Yes::Auth::Cerbos::ReadResourceAccess::PrincipalAttributes.call(
        #     principal: user,
        #     read_resource_accesses: accesses
        #   )
        class PrincipalAttributes
          class << self
            # @param principal [Yes::Auth::Principals::User, nil] the principal user
            # @param read_resource_accesses [Array, ActiveRecord::Relation] read resource accesses
            # @return [HashWithIndifferentAccess] Cerbos principal attributes
            def call(principal: nil, read_resource_accesses: [])
              return {} unless principal

              {
                **(principal.auth_attributes || {}),
                read_resource_access: read_attributes(read_resource_accesses)
              }.with_indifferent_access
            end

            private

            # @param accesses [Array, ActiveRecord::Relation] read resource accesses
            # @return [Hash] nested hash of read resource access attributes
            def read_attributes(accesses)
              attributes = Hash.new { |h, k| h[k] = Hash.new(&h.default_proc) }

              accesses.each do |access|
                next unless access.authorization_complete?

                attributes[access.service][access.scope][access.resource_type][access.role&.resource_authorization_name][access.resource_id] =
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
