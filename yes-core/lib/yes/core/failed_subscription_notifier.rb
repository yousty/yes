# frozen_string_literal: true

module Yes
  module Core
    # Reports a permanently dead pg_eventstore subscription to Sentry.
    #
    # pg_eventstore calls its +failed_subscription_notifier+ exactly once, when a
    # subscription exhausts its restarts and stays dead — it is the gem's only
    # death signal, and without it that death is silent (B2BY-5189). Per-failure
    # errors are only recorded on the subscription row, never raised into Sentry.
    class FailedSubscriptionNotifier
      # @param subscription [PgEventstore::Subscription]
      # @param error [StandardError]
      # @return [void]
      def call(subscription, error)
        Sentry.with_scope do |scope|
          scope.set_tags(failed_subscription_notifier: true) # used in Sentry Alerts

          Sentry.capture_exception(
            error,
            # a death report must never be swallowed by Sentry's excluded_exceptions
            hint: { ignore_exclusions: true },
            extra: { id: subscription.id, set: subscription.set, name: subscription.name }
          )
        end
      end
    end
  end
end
