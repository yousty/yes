# frozen_string_literal: true

require_relative '../rails_helper'

RSpec.describe 'MessageBus user lookup' do
  subject do
    post "/message-bus/#{client_id}/poll?#{params.to_param}",
         env: { 'rack.input' => StringIO.new(body) },
         headers:,
         as: :json
  end

  let(:client_id) { 'some-id' }
  let(:body) { { channel_name => 0 }.to_json }
  let(:params) { { dlt: 't' } } # disable long polling
  let(:headers) { { 'Authorization' => "Token #{jwt_sign_in(identity_id: user_uuid1)}" } }
  let(:channel_name) { 'some-channel' }
  let(:first_message) { { foo: :bar } }
  let(:second_message) { { bar: :baz } }
  let(:user_uuid1) { SecureRandom.uuid }
  let(:user_uuid2) { SecureRandom.uuid }

  # MessageBus middleware bypasses Rails response handling, so parsed_body
  # does not auto-parse JSON. Use explicit JSON.parse instead.
  let(:parsed_response) { response.parsed_body }

  before do
    MessageBus.publish(channel_name, first_message, user_ids: [user_uuid1])
    MessageBus.publish(channel_name, second_message, user_ids: [user_uuid2])
  end

  context 'when auth is present' do
    it 'returns messages, belonging to the authenticated user' do
      subject
      aggregate_failures do
        expect(parsed_response).to include(a_hash_including('data' => first_message.as_json))
        expect(parsed_response).not_to include(a_hash_including('data' => second_message.as_json))
      end
    end
  end

  context 'when auth is absent' do
    let(:headers) { {} }

    it 'does not publish any messages' do
      subject
      aggregate_failures do
        expect(parsed_response).not_to include(a_hash_including('data' => first_message.as_json))
        expect(parsed_response).not_to include(a_hash_including('data' => second_message.as_json))
      end
    end
  end
end
