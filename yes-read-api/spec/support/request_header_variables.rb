# frozen_string_literal: true

RSpec.shared_context :request_header_variables do
  let(:media_type) { 'application/json; charset=utf-8' }
  let(:access_token) { nil }
  let(:custom_headers) { {} }

  let(:request_headers) do
    {
      'Content-Type' => media_type,
      'Accept' => media_type,
      'Authorization' => access_token ? "Bearer #{access_token}" : nil
    }.merge(custom_headers).compact_blank
  end
end
