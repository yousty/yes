# frozen_string_literal: true

require 'yes/core/test_support/jwt_helpers'

# Delegate to shared implementation in yes-core.
# @see Yes::Core::TestSupport::JwtHelpers
module JwtHelpers
  include Yes::Core::TestSupport::JwtHelpers
end
