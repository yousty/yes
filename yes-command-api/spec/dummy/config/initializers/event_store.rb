# frozen_string_literal: true

Yousty::Eventsourcing.configure do |config|
  config.command_notifier_classes = [Yousty::Eventsourcing::CommandNotifiers::MessageBusNotifier]
end

PgEventstore.configure do |config|
  config.pg_uri = 'postgresql://postgres:postgres@localhost:5532/eventstore'
end
