# frozen_string_literal: true

RSpec.describe Yes::Core::ProcessManagers::CommandRunner do
  subject(:command_runner) { described_class.new(command_api_client:) }

  let(:command_api_client) { instance_double('ServiceClient') }
  let(:access_token_client) { instance_double('AccessTokenClient') }
  let(:logger) { instance_double('Logger') }

  before do
    allow(Yes::Core::ProcessManagers::AccessTokenClient).to receive(:new).and_return(access_token_client)
    allow(Rails).to receive(:logger).and_return(logger)
  end

  describe '#initialize' do
    it 'sets up the command runner with correct attributes' do
      aggregate_failures do
        expect(command_runner.send(:command_api_client)).to eq(command_api_client)
        expect(command_runner.send(:access_token_client)).to eq(access_token_client)
        expect(command_runner.send(:logger)).to eq(logger)
      end
    end
  end

  describe '#publish' do
    let(:client_id) { 'test_client_id' }
    let(:client_secret) { 'test_client_secret' }
    let(:commands_data) { [{ command: 'test_command', payload: { key: 'value' } }] }
    let(:access_token) { 'test_access_token' }
    let(:channel) { '/process_managers/command_runner' }
    let(:response) { instance_double('Faraday::Response', success?: true) }

    before do
      allow(access_token_client).to receive(:call).with(client_id:, client_secret:).and_return(access_token)
      allow(command_api_client).to receive(:call).with(access_token:, commands_data:, channel:).and_return(response)
      allow(command_runner).to receive(:channel).and_return(channel)
    end

    it 'publishes commands successfully' do
      result = command_runner.send(:publish, client_id:, client_secret:, commands_data:)
      expect(result).to eq(response)
    end

    context 'when no API client is available' do
      subject(:command_runner) { described_class.new }

      it 'raises an ArgumentError' do
        expect {
          command_runner.send(:publish, client_id:, client_secret:, commands_data:)
        }.to raise_error(ArgumentError, /No API client available/)
      end
    end

    context 'when the API request fails' do
      let(:response) do
        instance_double(
          'Faraday::Response',
          success?: false,
          env: double(url: 'http://example.com', request_body: '{}', request_headers: { 'Authorization' => 'Bearer token' }),
          body: '{}',
          status: 400
        )
      end

      before do
        allow(logger).to receive(:error)
      end

      it 'raises a ProcessManagers::Base::Error' do
        expect {
          command_runner.send(:publish, client_id:, client_secret:, commands_data:)
        }.to raise_error(Yes::Core::ProcessManagers::Base::Error, /Process Manager: failed to send commands/)

        expect(logger).to have_received(:error)
      end
    end
  end

  describe '#channel' do
    it 'returns the correct channel name' do
      expect(command_runner.send(:channel)).to eq('/yes/core')
    end
  end

  describe '#process_manager_error!' do
    let(:response) do
      instance_double(
        'Faraday::Response',
        env: double(url: 'http://example.com', request_body: '{}', request_headers: { 'Authorization' => 'Bearer token' }),
        body: '{}',
        status: 400
      )
    end

    before do
      allow(logger).to receive(:error)
    end

    it 'logs the error and raises a ProcessManagers::Base::Error' do
      expect {
        command_runner.send(:process_manager_error!, response, error_msg: 'Test error')
      }.to raise_error(Yes::Core::ProcessManagers::Base::Error) do |error|
        aggregate_failures do
          expect(error.message).to eq('Process Manager: failed to send commands')
          expect(error.extra).to include(:error_msg, :request, :response)
        end
      end

      expect(logger).to have_received(:error)
    end
  end
end
