# frozen_string_literal: true

RSpec.describe Yes::Core::ProcessManagers::AccessTokenClient do
  subject(:client) { described_class.new }

  let(:client_id) { 'test_client_id' }
  let(:client_secret) { 'test_client_secret' }
  let(:access_token) { 'test_access_token' }
  let(:auth_url) { 'http://auth-cluster-ip-service:3000/v1' }

  describe '#call' do
    context 'when the request is successful' do
      before do
        stub_request(:post, "#{auth_url}/oauth/token")
          .with(
            body: {
              client_id:,
              client_secret:,
              grant_type: 'client_credentials'
            }
          )
          .to_return(
            status: 200,
            body: { access_token: }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'returns the access token' do
        expect(client.call(client_id:, client_secret:)).to eq(access_token)
      end
    end

    context 'when the request fails' do
      before do
        stub_request(:post, "#{auth_url}/oauth/token")
          .to_return(
            status: 400,
            body: { error: 'invalid_client' }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises an AccessTokenClient::Error' do
        expect { client.call(client_id:, client_secret:) }.to raise_error(described_class::Error)
      end
    end

    context 'when the response is successful but does not contain an access token' do
      before do
        stub_request(:post, "#{auth_url}/oauth/token")
          .to_return(
            status: 200,
            body: {}.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'raises an AccessTokenClient::Error' do
        expect { client.call(client_id:, client_secret:) }.to raise_error(described_class::Error)
      end
    end
  end

  describe described_class::Error do
    subject(:error) { described_class.new('Test error', extra: { key: 'value' }) }

    it 'initializes with a message and extra information' do
      aggregate_failures do
        expect(error.message).to eq('Test error')
        expect(error.extra).to eq({ key: 'value' })
      end
    end
  end
end
