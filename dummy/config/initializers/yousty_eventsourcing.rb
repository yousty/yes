# frozen_string_literal: true

Yousty::Eventsourcing.configure do |config|
  # This config option seems to be unavailable in the current version
  # config.command_notifier_classes = [
  #   Yes::Core::CommandNotifiers::MessageBusNotifier
  # ]
end
