# frozen_string_literal: true

require_relative '../rails_helper'

RSpec.describe 'MessageBus filters' do
  subject do
    post "/message-bus/#{client_id}/poll?#{params.to_param}",
         env: { 'rack.input' => StringIO.new(body) },
         as: :json
  end

  let(:client_id) { 'some-id' }
  let(:body) { { channel_name => last_viewed_id }.to_json }
  let(:params) { { dlt: 't' } } # disable long polling
  let(:last_viewed_id) { 0 }
  let(:channel_name) { 'some-channel' }
  let(:first_message) { { command: 'assign', published_at: 50, batch_id: 1, type: 'bar' } }
  let(:second_message) { { command: 'remove', published_at: 100, batch_id: 2, type: 'baz' } }

  # MessageBus middleware bypasses Rails response handling, so parsed_body
  # does not auto-parse JSON. Use explicit JSON.parse instead.
  let(:parsed_response) { response.parsed_body }

  before do
    MessageBus.publish(channel_name, first_message)
    MessageBus.publish(channel_name, second_message)
  end

  context 'when there are no filters' do
    it 'returns all events from the channel' do
      subject
      aggregate_failures do
        expect(parsed_response).to include(a_hash_including('data' => first_message.as_json))
        expect(parsed_response).to include(a_hash_including('data' => second_message.as_json))
      end
    end
  end

  context 'when :batch_id filter is provided' do
    before do
      params[:batch_id] = 2
    end

    it 'returns messages, filtered by the given batch id' do
      subject
      aggregate_failures do
        expect(parsed_response).not_to include(a_hash_including('data' => first_message.as_json))
        expect(parsed_response).to include(a_hash_including('data' => second_message.as_json))
      end
    end
  end

  context 'when :type filter is provided' do
    before do
      params[:type] = 'bar'
    end

    it 'returns messages, filtered by the given type' do
      subject
      aggregate_failures do
        expect(parsed_response).to include(a_hash_including('data' => first_message.as_json))
        expect(parsed_response).not_to include(a_hash_including('data' => second_message.as_json))
      end
    end
  end

  context 'when :command filter is provided' do
    before do
      params[:command] = 'assign'
    end

    it 'returns messages, filtered by the given command name' do
      subject
      aggregate_failures do
        expect(parsed_response).to include(a_hash_including('data' => first_message.as_json))
        expect(parsed_response).not_to include(a_hash_including('data' => second_message.as_json))
      end
    end
  end

  context 'when :since filter is provided' do
    before do
      params[:since] = 75
    end

    it 'returns messages, filtered by the published time' do
      subject
      aggregate_failures do
        expect(parsed_response).not_to include(a_hash_including('data' => first_message.as_json))
        expect(parsed_response).to include(a_hash_including('data' => second_message.as_json))
      end
    end
  end

  describe 'filtering by starting position' do
    let(:last_viewed_id) { MessageBus.last_id(channel_name) - 1 }

    it 'returns all messages, starting after provided id' do
      subject
      aggregate_failures do
        expect(parsed_response).not_to include(a_hash_including('data' => first_message.as_json))
        expect(parsed_response).to include(a_hash_including('data' => second_message.as_json))
      end
    end
  end
end
