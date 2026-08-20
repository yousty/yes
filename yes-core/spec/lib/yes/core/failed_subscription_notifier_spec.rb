# frozen_string_literal: true

RSpec.describe Yes::Core::FailedSubscriptionNotifier do
  subject(:notify) { described_class.new.call(subscription, error) }

  let(:subscription) { PgEventstore::Subscription.new(id: 42, set: 'Yes', name: 'SomeProcessManager') }
  let(:error) { StandardError.new('handler exploded') }
  let(:sentry) { class_double('Sentry') }
  let(:scope) { double('Sentry::Scope', set_tags: nil) }

  before do
    # Sentry is not a dependency of this gem — the railtie only registers the
    # notifier when the host app loaded it, so the constant is stubbed here.
    stub_const('Sentry', sentry)
    allow(sentry).to receive(:with_scope).and_yield(scope)
    allow(sentry).to receive(:capture_exception)
  end

  it 'reports the death to Sentry with the subscription identity' do
    notify

    aggregate_failures do
      expect(scope).to have_received(:set_tags).with(failed_subscription_notifier: true)
      expect(sentry).to have_received(:capture_exception).with(
        error,
        hint: { ignore_exclusions: true },
        extra: { id: 42, set: 'Yes', name: 'SomeProcessManager' }
      )
    end
  end
end
