# frozen_string_literal: true

RSpec.describe Yes::Core::Middlewares::Encryptor do
  include EventHelpers

  let(:instance) do
    described_class.new(DummyRepository.new)
  end
  let(:data) do
    {
      'user_id' => 'dab48d26-e4f8-41fc-a9a8-59657e590716',
      'name' => 'Anakin Skywalker',
      'secret_name' => 'Darth Vader'
    }
  end

  describe '#serialize' do
    subject { instance.serialize(event) }

    let(:event) { EncryptedEvent.new(data: data.dup) }

    it { is_expected.to be_a(Yes::Core::Event) }

    it 'has correct structure' do
      aggregate_failures do
        expect(subject.data).to(
          eq(
            'user_id' => 'dab48d26-e4f8-41fc-a9a8-59657e590716',
            'name' => 'Anakin Skywalker',
            'secret_name' => 'es_encrypted',
            'es_encrypted' => DummyRepository.encrypt(data.slice('secret_name').to_json)
          )
        )
        expect(subject.metadata).to match(hash_including('encryption'))
      end
    end

    context 'when event class does not have encryption schema' do
      let(:event) { Yes::Core::Event.new(data: data.dup) }

      it 'keeps event as is' do
        aggregate_failures do
          expect(subject.data).to eq(data)
          expect(subject.metadata).to eq({})
        end
      end
    end
  end

  describe '#deserialize' do
    subject { instance.deserialize(event) }

    let(:encryption_metadata) do
      {
        iv: 'DarthSidious',
        key: 'dab48d26-e4f8-41fc-a9a8-59657e590716',
        attributes: %i[secret_name]
      }
    end
    let(:encrypted_data) do
      {
        'user_id' => 'dab48d26-e4f8-41fc-a9a8-59657e590716',
        'name' => 'Anakin Skywalker',
        'secret_name' => 'es_encrypted',
        'es_encrypted' => DummyRepository.encrypt(message_to_encrypt)
      }
    end
    let(:decrypted_data) do
      {
        'user_id' => 'dab48d26-e4f8-41fc-a9a8-59657e590716',
        'name' => 'Anakin Skywalker',
        'secret_name' => 'Darth Vader'
      }
    end
    let!(:event) do
      event = EncryptedEvent.new(
        data: encrypted_data,
        metadata: { encryption: encryption_metadata }
      )
      stream = PgEventstore::Stream.new(context: 'SomeCtx', stream_name: 'MyStream', stream_id: '1')
      append_and_reload_event(stream, event)
    end
    let(:message_to_encrypt) do
      decrypted_data.slice('secret_name').to_json
    end

    before do
      DummyRepository.new.encrypt(
        key: DummyRepository::Key.new(id: decrypted_data['user_id']),
        message: message_to_encrypt
      )
    end

    it 'returns decrypted event' do
      aggregate_failures do
        expect(subject).to be_a(EncryptedEvent)
        expect(subject.data).to eq(decrypted_data)
        expect(subject.data).not_to include('es_encrypted')
        expect(subject.metadata).to include('encryption')
      end
    end
  end
end
