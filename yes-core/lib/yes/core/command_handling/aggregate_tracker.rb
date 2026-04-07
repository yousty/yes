# frozen_string_literal: true

module Yes
  module Core
    module CommandHandling
      # Tracks external aggregate access during command handling
      class AggregateTracker
        # @return [Array<Hash>] List of accessed external aggregates with their revisions
        attr_reader :accessed_external_aggregates

        def initialize
          @accessed_external_aggregates = []
        end

        # Tracks an external aggregate access
        #
        # @param attribute_name [Symbol] The attribute name
        # @param id [String] The aggregate ID
        # @param revision [Integer] The aggregate revision
        # @param context [String] The context name
        # @return [void]
        def track(attribute_name:, id:, revision:, context:)
          accessed_external_aggregates << {
            id:,
            context:,
            name: attribute_name.to_s.camelize,
            revision:
          }
        end
      end
    end
  end
end
