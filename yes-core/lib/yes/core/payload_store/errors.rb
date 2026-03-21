# frozen_string_literal: true

module Yes
  module Core
    module PayloadStore
      # Error classes for payload store operations
      module Errors
        class MissingClient < Error; end
        class ClientError < Error; end
      end
    end
  end
end
