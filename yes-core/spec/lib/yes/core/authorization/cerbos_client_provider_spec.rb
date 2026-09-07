# frozen_string_literal: true

RSpec.describe Yes::Core::Authorization::CerbosClientProvider do
  let(:authorizer_class) do
    Class.new do
      class << self
        include Yes::Core::Authorization::CerbosClientProvider

        def client
          cerbos_client
        end
      end
    end
  end

  let(:cerbos_client) { instance_double(Cerbos::Client) }
  let(:cerbos_url) { 'cerbos.test:3593' }
  let(:cerbos_tls) { false }
  let(:channel_args) { { 'grpc.enable_retries' => 0 } }

  before do
    Yes::Core.configuration.cerbos_url = cerbos_url
    Yes::Core.configuration.cerbos_tls = cerbos_tls
    Yes::Core.configuration.cerbos_grpc_channel_args = channel_args

    allow(Cerbos::Client).to receive(:new).and_return(cerbos_client)
  end

  after do
    Yes::Core.configuration.cerbos_tls = true
    Yes::Core.configuration.cerbos_grpc_channel_args = Yes::Core::Authorization::CerbosGrpcRetryPolicy.channel_args
  end

  describe '#cerbos_client' do
    subject { authorizer_class.client }

    it 'builds the client from the configuration' do
      subject

      expect(Cerbos::Client).to have_received(:new).with(cerbos_url, tls: cerbos_tls, grpc_channel_args: channel_args)
    end

    it 'returns the client' do
      expect(subject).to be(cerbos_client)
    end

    context 'when called repeatedly' do
      let(:other_authorizer_class) do
        Class.new do
          class << self
            include Yes::Core::Authorization::CerbosClientProvider

            def client
              cerbos_client
            end
          end
        end
      end

      it 'shares one client across calls and authorizer classes' do
        aggregate_failures do
          expect(authorizer_class.client).to be(cerbos_client)
          expect(other_authorizer_class.client).to be(cerbos_client)
          expect(Cerbos::Client).to have_received(:new).once
        end
      end
    end

    context 'when the process has forked' do
      let(:child_pid) { Process.pid + 1 }

      before do
        authorizer_class.client
        allow(Process).to receive(:pid).and_return(child_pid)
      end

      it 'builds a new client in the child process' do
        subject

        expect(Cerbos::Client).to have_received(:new).twice
      end
    end
  end

  describe '.reset!' do
    subject { described_class.reset! }

    before { authorizer_class.client }

    it 'drops the memoized client' do
      subject
      authorizer_class.client

      expect(Cerbos::Client).to have_received(:new).twice
    end
  end
end
