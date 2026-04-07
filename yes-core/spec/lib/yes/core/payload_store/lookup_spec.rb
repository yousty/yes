# frozen_string_literal: true

RSpec.describe Yes::Core::PayloadStore::Lookup do
  describe '#call' do
    subject { lookup.call(event) }

    let(:lookup) { described_class.new }
    let(:user_id) { SecureRandom.uuid }
    let(:ps_ref_description) { "payload-store:#{SecureRandom.uuid}" }
    let(:ps_ref_bio) { "payload-store:#{SecureRandom.uuid}" }

    let(:event) do
      Dummy::WithLargePayload.new(
        data: {
          'description' => ps_ref_description,
          'bio' => ps_ref_bio,
          'user_id' => user_id
        }
      )
    end

    context 'when event has payload store references' do
      context 'when there is a valid client' do
        let(:client) { double('Client') }
        let(:resolved_description) { double('Payload', attributes: { key: ps_ref_description, value: 'long description' }) }
        let(:resolved_bio) { double('Payload', attributes: { key: ps_ref_bio, value: 'long bio' }) }
        let(:response) { double('Response', success?: true) }

        before do
          allow(response).to receive(:value!).and_return([resolved_description, resolved_bio])
          allow(client).to receive(:get_payloads).and_return(response)
          Yes::Core.configuration.payload_store_client = client
        end

        after do
          Yes::Core.configuration.payload_store_client = nil
        end

        it 'resolves payload store references' do
          aggregate_failures do
            expect(subject['description']).to eq('long description')
            expect(subject['bio']).to eq('long bio')
          end
        end

        it 'does not include non-payload-store fields' do
          expect(subject).not_to have_key('user_id')
        end

        context 'when payload store request fails' do
          let(:response) { double('Response', success?: false, failure: 'failure') }

          it 'returns an empty hash' do
            expect(subject).to eq({})
          end
        end
      end

      context 'when there is no client' do
        before do
          Yes::Core.configuration.payload_store_client = nil
        end

        it 'raises MissingClient error' do
          expect { subject }.to raise_error(Yes::Core::PayloadStore::Errors::MissingClient)
        end
      end
    end

    context 'when event has no payload store references' do
      let(:event) { Yes::Core::Event.new(data: { 'bio' => 'about me' }) }

      it 'returns an empty hash' do
        expect(subject).to eq({})
      end
    end
  end
end
