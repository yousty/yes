# frozen_string_literal: true

MessageBus.configure(backend: :active_record, pubsub_redis_url: 'redis://localhost:6479/1')
