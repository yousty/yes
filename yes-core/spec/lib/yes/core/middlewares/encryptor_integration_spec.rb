# frozen_string_literal: true

# End-to-end coverage of the encryptor middlewares as pg_eventstore actually applies them.
#
# encryptor_spec.rb unit-tests #serialize/#deserialize by calling them directly, which cannot catch changes in
# WHEN pg_eventstore invokes them. pg_eventstore 3.0 started running #deserialize on append_to_stream as well
# as on reads; every yes-core write site therefore passes `middlewares: Middlewares.for_write`, which swaps
# :encryptor for :write_encryptor so an append does not pay a decrypt round trip for a payload nobody reads.
RSpec.describe 'Encryptor middleware integration' do
  let(:key_repository) { DummyRepository.new }
  let(:user_id) { SecureRandom.uuid }
  let(:stream) do
    PgEventstore::Stream.new(context: 'EncryptionCtx', stream_name: 'MyStream', stream_id: SecureRandom.uuid)
  end
  let(:data) do
    { 'user_id' => user_id, 'name' => 'Anakin Skywalker', 'secret_name' => 'Darth Vader' }
  end
  let(:append) do
    PgEventstore.client.append_to_stream(
      stream, EncryptedEvent.new(data: data.dup), middlewares: Yes::Core::Middlewares.for_write
    )
  end
  let(:at_rest) do
    PgEventstore.client.read(stream, middlewares: Yes::Core::Middlewares.without(Yes::Core::Middlewares::ENCRYPTOR)).last
  end

  around do |example|
    # Registered last so :with_indifferent_access stays first, matching how the host applications register it.
    Yes::Core::Middlewares.register_encryptor(key_repository)
    example.run
  ensure
    PgEventstore.config.middlewares.except!(
      Yes::Core::Middlewares::ENCRYPTOR, Yes::Core::Middlewares::WRITE_ENCRYPTOR
    )
  end

  it 'stores the protected attribute encrypted' do
    append

    aggregate_failures do
      expect(at_rest.data['secret_name']).to eq('es_encrypted')
      expect(at_rest.data['es_encrypted']).to eq(DummyRepository.encrypt(data.slice('secret_name').to_json))
      expect(at_rest.data['name']).to eq('Anakin Skywalker')
    end
  end

  it 'decrypts on read' do
    append

    expect(PgEventstore.client.read(stream).last.data['secret_name']).to eq('Darth Vader')
  end

  # Was pinned the other way round while the write path used the default middleware list. The whole point of
  # :write_encryptor is that the appended event comes back exactly as it went to disk.
  it 'does not decrypt the event returned by append_to_stream' do
    aggregate_failures do
      expect(append.data['secret_name']).to eq('es_encrypted')
      expect(append.data['es_encrypted']).to be_present
      expect(append.metadata['encryption']).to be_present
    end
  end

  it 'keeps the other middlewares on the write list' do
    aggregate_failures do
      expect(append.metadata['created_at']).to be_present
      expect(append.data).to be_a(ActiveSupport::HashWithIndifferentAccess)
    end
  end

  it 'performs no decrypt work on the write path' do
    append

    aggregate_failures do
      expect(DummyRepository.calls[:encrypt]).to eq(1)
      expect(DummyRepository.calls[:decrypt]).to eq(0)
    end
  end

  it 'still decrypts once per event on the read path' do
    append
    PgEventstore.client.read(stream)

    expect(DummyRepository.calls[:decrypt]).to eq(1)
  end

  # Fail-safe: for_write falls back to the full list rather than producing one with no encryptor in it, so
  # encryption at rest survives the misconfiguration.
  context 'when the write encryptor is not registered' do
    before { PgEventstore.config.middlewares.delete(Yes::Core::Middlewares::WRITE_ENCRYPTOR) }

    it 'falls back to the full middleware list' do
      expect(Yes::Core::Middlewares.for_write).to include(Yes::Core::Middlewares::ENCRYPTOR)
    end

    it 'still encrypts at rest' do
      append

      expect(at_rest.data['secret_name']).to eq('es_encrypted')
    end
  end
end
