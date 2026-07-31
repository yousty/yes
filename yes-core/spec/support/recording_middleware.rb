# frozen_string_literal: true

# Real (non-mock) PgEventstore middleware that records how often pg_eventstore invoked each hook.
#
# Lets specs assert WHICH middleware list a call site passed, without stubbing PgEventstore::Client and without
# needing an encrypted event class - the claim under test is about the list, not about ciphertext.
class RecordingMiddleware
  include PgEventstore::Middleware

  # @return [Integer]
  attr_reader :serialized

  # @return [Integer]
  attr_reader :deserialized

  def initialize
    @serialized = 0
    @deserialized = 0
  end

  # @param event [PgEventstore::Event]
  # @return [PgEventstore::Event]
  def serialize(event)
    @serialized += 1
    event
  end

  # @param event [PgEventstore::Event]
  # @return [PgEventstore::Event]
  def deserialize(event)
    @deserialized += 1
    event
  end
end
