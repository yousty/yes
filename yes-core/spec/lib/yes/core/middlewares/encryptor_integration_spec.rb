# frozen_string_literal: true

# End-to-end coverage of the encryptor middleware as pg_eventstore actually applies it.
#
# encryptor_spec.rb unit-tests #serialize/#deserialize by calling them directly, which
# cannot catch changes in WHEN pg_eventstore invokes them. pg_eventstore 3.0 started
# running #deserialize on append_to_stream as well as on reads, and no spec in this repo
# could see that: nothing here registers an encryptor in config.middlewares, and the host
# applications gate their registration on `!Rails.env.test?`, so their suites cannot see
# it either.
RSpec.describe 'Encryptor middleware integration' do
  let(:key_repository) { DummyRepository.new }
  let(:user_id) { SecureRandom.uuid }
  let(:stream) do
    PgEventstore::Stream.new(context: 'EncryptionCtx', stream_name: 'MyStream', stream_id: SecureRandom.uuid)
  end
  let(:data) do
    { 'user_id' => user_id, 'name' => 'Anakin Skywalker', 'secret_name' => 'Darth Vader' }
  end
  let(:append) { PgEventstore.client.append_to_stream(stream, EncryptedEvent.new(data: data.dup)) }

  around do |example|
    # Assigned last so :with_indifferent_access stays first, matching how the host
    # applications register it.
    PgEventstore.config.middlewares[:encryptor] = Yes::Core::Middlewares::Encryptor.new(key_repository)
    example.run
  ensure
    PgEventstore.config.middlewares.delete(:encryptor)
  end

  it 'stores the protected attribute encrypted' do
    append
    at_rest = PgEventstore.client.read(stream, middlewares: Yes::Core::Middlewares.without(:encryptor)).last

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

  # pg_eventstore 3.0 runs #deserialize on append too, so the returned event comes back
  # already decrypted. Pinned here so a future change to that behaviour fails in this
  # spec rather than silently in a consumer.
  it 'returns a decrypted event from append_to_stream' do
    expect(append.data['secret_name']).to eq('Darth Vader')
  end
end
