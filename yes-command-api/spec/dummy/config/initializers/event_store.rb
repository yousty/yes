# frozen_string_literal: true

Yes::Core.configure do |config|
  config.command_notifier_classes = [Yes::Command::Api::Commands::Notifiers::MessageBus]
end

PgEventstore.configure do |config|
  config.pg_uri = ENV.fetch('PG_EVENTSTORE_URI', 'postgresql://postgres:postgres@localhost:5532/eventstore')
end
