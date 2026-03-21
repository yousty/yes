# frozen_string_literal: true

require 'yes/core/test_support/event_helpers'

# Delegate to shared implementation in yes-core.
# @see Yes::Core::TestSupport::EventHelpers
module EventHelpers
  include Yes::Core::TestSupport::EventHelpers
end
