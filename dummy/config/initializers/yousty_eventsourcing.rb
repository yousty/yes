# frozen_string_literal: true

Yousty::Eventsourcing.configure do |config|
  config.command_notifier_classes = [
    Yes::Core::CommandNotifiers::MessageBusNotifier
  ]
end
