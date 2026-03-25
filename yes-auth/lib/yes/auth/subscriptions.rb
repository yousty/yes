# frozen_string_literal: true

module Yes
  module Auth
    # Wires authorization event builders to the appropriate subscriptions.
    #
    # Role, User, WriteResourceAccess, and ReadResourceAccess builders
    # are registered via the yes-core ReadModel::Builder pattern.
    class Subscriptions
      # @param subscriptions [Object] the subscription registry
      # @raise [NotImplementedError] builders need to be ported from yousty-eventsourcing
      def self.call(subscriptions)
        # TODO: Port builders from yousty-eventsourcing when needed
        raise NotImplementedError, 'Auth subscription builders need to be ported from yousty-eventsourcing'
      end
    end
  end
end
