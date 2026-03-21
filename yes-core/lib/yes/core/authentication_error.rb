# frozen_string_literal: true

module Yes
  module Core
    # Raised when authentication fails in API controllers
    class AuthenticationError < Error; end
  end
end
