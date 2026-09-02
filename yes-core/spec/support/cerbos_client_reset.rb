# frozen_string_literal: true

# The Cerbos client is memoized per process; drop it after every example so a stubbed
# `Cerbos::Client.new` never leaks into the next one.
RSpec.configure do |config|
  config.after { Yes::Core::Authorization::CerbosClientProvider.reset! }
end
