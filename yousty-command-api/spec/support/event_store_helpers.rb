# frozen_string_literal: true

module EventStoreHelpers
  def arrange(stream_name, events = [])
    EventStoreClient.client.append_to_stream(stream_name, events)
    EventStoreClient.client.read(stream_name)
  end

  def expect_events(actual, expected)
    expects = expected.map(&:data)
    expect(actual.map(&:data)).to eq(expects)
  end

  def read_stream(stream)
    EventStoreClient.client.read(stream)
  rescue EventStoreClient::StreamNotFoundError
    []
  end
end
