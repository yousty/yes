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
        # @param instance [Object] The aggregate instance
        # @param context [String] The context name
        # @return [void]
        def track(attribute_name:, instance:, context:)
          return unless instance

          accessed_external_aggregates << {
            id: instance.id,
            context:,
            name: attribute_name.to_s.camelize,
            revision: instance.revision
          }
        end
      end
    end
  end
end
