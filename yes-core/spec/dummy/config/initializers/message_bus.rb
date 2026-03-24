# frozen_string_literal: true

return unless defined?(MessageBus)

if ENV.fetch('MESSAGE_BUS_ENABLED', 'false').to_s == 'true'
  MessageBus.configure(
    backend: :active_record,
    pubsub_redis_url: 'redis://redis:6379/2',
    long_polling_interval: ENV.fetch('MESSAGE_BUS_POLLING_INTERVAL_SECONDS', 30).to_i * 1000
  )
  MessageBus.configure(on_middleware_error: proc do |_env, e|
    Rails.logger.debug { "MessageBus error: #{e.inspect}" }
    Rails.logger.debug { "MessageBus error backtrace: #{e.backtrace.join("\n")}" }
    nil
  end)
else
  MessageBus.off
end
