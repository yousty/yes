# frozen_string_literal: true

RSpec.describe Yes::Core::ProcessManagers::ServiceClient do
  subject(:client) { described_class.new(service) }

  let(:service) { 'test_service' }
  let(:access_token) { 'test_token' }
  let(:channel) { 'test_channel' }
  let(:commands_data) { [{ command: 'test_command', data: 'test_data' }] }

  describe '#initialize' do
    it 'sets the service_url from environment variable if available' do
      allow(ENV).to receive(:fetch).with('TEST_SERVICE_SERVICE_URL', anything).and_return('http://test-service.com')
      expect(client.send(:service_url)).to eq('http://test-service.com')
    end

    it 'sets the default service_url if environment variable is not available' do
      allow(ENV).to receive(:fetch).and_call_original
      expect(client.send(:service_url)).to eq('http://test-service-cluster-ip-service:3000')
    end
  end

  describe '#call' do
    let(:faraday_connection) { instance_double(Faraday::Connection) }
    let(:faraday_request) { instance_double(Faraday::Request) }

    before do
      allow(Faraday).to receive(:new).and_return(faraday_connection)
      allow(faraday_connection).to receive(:post).and_yield(faraday_request)
      allow(faraday_request).to receive(:url)
      allow(faraday_request).to receive(:body=)
    end

    it 'sends a POST request to the correct endpoint' do
      client.call(access_token:, commands_data:, channel:)
      expect(faraday_request).to have_received(:url).with('/v1/commands')
    end

    it 'sets the correct request body' do
      client.call(access_token:, commands_data:, channel:)
      expect(faraday_request).to have_received(:body=).with({ channel:, commands: commands_data })
    end

    it 'raises an ArgumentError if access_token is nil' do
      expect {
        client.call(access_token: nil, commands_data:, channel:)
      }.to raise_error(ArgumentError, 'channel and access_token is required')
    end

    it 'raises an ArgumentError if channel is nil' do
      expect {
        client.call(access_token:, commands_data:, channel: nil)
      }.to raise_error(ArgumentError, 'channel and access_token is required')
    end
  end
end
