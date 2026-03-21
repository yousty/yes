# frozen_string_literal: true

module Yes
  module Core
    module Middlewares
      # PgEventstore middleware that converts event data and metadata
      # to HashWithIndifferentAccess, allowing both string and symbol key access.
      class WithIndifferentAccess
        include PgEventstore::Middleware

        # @param event [PgEventstore::Event]
        # @return [PgEventstore::Event]
        def serialize(event)
          event.metadata = event.metadata.with_indifferent_access
          event.data = event.data.with_indifferent_access
          event
        end
        alias deserialize serialize
      end
    end
  end
end
