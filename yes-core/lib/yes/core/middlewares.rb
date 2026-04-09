# frozen_string_literal: true

module Yes
  module Core
    module Middlewares
      class << self
        # Returns middleware keys excluding the specified one.
        #
        # @param middleware_name [Symbol] the middleware key to exclude
        # @return [Array<Symbol>] remaining middleware keys
        def without(middleware_name)
          PgEventstore.config.middlewares.except(middleware_name).keys
        end
      end
    end
  end
end
