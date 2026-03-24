# frozen_string_literal: true

require 'sidekiq/web'

Sidekiq::Web.use(Rack::Auth::Basic) do |user, password|
  [user, password] ==
    [ENV.fetch('SIDEKIQ_USERNAME', nil), ENV.fetch('SIDEKIQ_PASSWORD', nil)]
end

# Disable Sidekiq's strict arguments. We have ActiveJob which ensures that job's arguments are
# properly serialized.
Sidekiq.strict_args!(false)

Sidekiq.configure_client do |config|
  config.redis = { url: "redis://#{ENV.fetch('REDIS_HOST', nil)}:6479/" }
end

Sidekiq.configure_server do |config|
  ActiveRecord::Base.logger = nil
  logger = Rails.logger
  logger.level = :debug

  config.logger = logger

  config.error_handlers << proc { |e, context| Rails.logger.error("Sidekiq error: #{e.message}", context:) }
  config.redis = { url: "redis://#{ENV.fetch('REDIS_HOST', nil)}:6479/" }
end

Sidekiq.default_job_options = { retry: 0 }
