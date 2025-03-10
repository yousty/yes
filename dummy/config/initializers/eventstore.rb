# frozen_string_literal: true

require 'pg_eventstore'

PgEventstore.configure do |config|
  config.pg_uri = ENV.fetch('PG_EVENTSTORE_URI', 'postgresql://postgres:postgres@localhost:5532/eventstore')
  config.connection_pool_size = 20
end
