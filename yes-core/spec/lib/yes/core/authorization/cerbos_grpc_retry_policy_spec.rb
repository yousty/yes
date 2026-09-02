# frozen_string_literal: true

RSpec.describe Yes::Core::Authorization::CerbosGrpcRetryPolicy do
  describe '.channel_args' do
    subject(:channel_args) { described_class.channel_args }

    let(:service_config) { JSON.parse(channel_args['grpc.service_config']) }
    let(:method_config) { service_config.fetch('methodConfig').first }

    it 'enables retries on the channel' do
      expect(channel_args['grpc.enable_retries']).to eq(1)
    end

    it 'scopes the retry policy to the Cerbos service' do
      expect(method_config['name']).to eq([{ 'service' => 'cerbos.svc.v1.CerbosService' }])
    end

    it 'retries UNAVAILABLE calls with exponential backoff' do
      expect(method_config['retryPolicy']).to eq(
        'maxAttempts' => 4,
        'initialBackoff' => '0.1s',
        'maxBackoff' => '1s',
        'backoffMultiplier' => 2,
        'retryableStatusCodes' => %w[UNAVAILABLE]
      )
    end
  end
end
