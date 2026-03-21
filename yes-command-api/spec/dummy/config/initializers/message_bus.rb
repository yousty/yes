# frozen_string_literal: true

MessageBus.configure(backend: :redis, backend_options: { url: 'redis://localhost:6479/1' })
