# frozen_string_literal: true

RSpec.describe Yes::Core::Middlewares::WriteEncryptor do
  let(:instance) { described_class.new(DummyRepository.new) }
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

    it 'encrypts exactly like the decrypting encryptor' do
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
  end

  describe '#deserialize' do
    subject { instance.deserialize(event) }

    let(:event) { instance.serialize(EncryptedEvent.new(data: data.dup)) }

    before do
      event # encrypt first, so the counters below reflect #deserialize alone
      DummyRepository.reset
    end

    it 'returns the event with its data still encrypted, without touching the key repository' do
      aggregate_failures do
        expect(subject).to be(event)
        expect(subject.data['secret_name']).to eq('es_encrypted')
        expect(DummyRepository.calls).to eq(find: 0, encrypt: 0, decrypt: 0)
      end
    end
  end
end
