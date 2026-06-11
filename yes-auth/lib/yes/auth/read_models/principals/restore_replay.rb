# frozen_string_literal: true

module Yes
  module Auth
    module ReadModels
      module Principals
        # Rebuilds a hard-deleted principals mirror row after an
        # `Authorization::...Restored` event.
        #
        # The `On...Removed` handlers delete mirror rows, and `Restored`
        # events carry no state snapshot. The aggregate's stream is replayed
        # through the builder's regular per-field event handlers to
        # reconstruct the row instead. Lifecycle events are excluded from the
        # replay: a `Removed` would delete (and freeze) the row mid-replay,
        # a `Restored` would recurse.
        class RestoreReplay
          CONTEXT = 'Authorization'
          LIFECYCLE_EVENT_TYPES = /(?:Removed|Restored)\z/

          # @param builder [Yes::Core::ReadModel::Builder] builder whose handlers replay the events
          # @param stream_name [String] aggregate stream name, e.g. 'WriteResourceAccess'
          def initialize(builder:, stream_name:)
            @builder = builder
            @stream_name = stream_name
          end

          # @param read_model [ActiveRecord::Base] the freshly (re)created mirror row
          # @param eventstore [PgEventstore::Client]
          # @return [void]
          def call(read_model, eventstore: PgEventstore.client)
            stream = PgEventstore::Stream.new(
              context: CONTEXT, stream_name: @stream_name, stream_id: read_model.id
            )
            eventstore.read_paginated(stream, options: { resolve_link_tos: true }).each do |events|
              events.each do |event|
                next if event.type.match?(LIFECYCLE_EVENT_TYPES)

                @builder.call(event, read_model:)
              end
            end
          end
        end
      end
    end
  end
end
