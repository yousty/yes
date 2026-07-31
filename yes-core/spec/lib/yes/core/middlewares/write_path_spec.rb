# frozen_string_literal: true

# test_support is ignored by the Zeitwerk loader (lib/yes/core.rb), so consumers require it explicitly.
require 'yes/core/test_support'

# Every yes-core write site must append through Middlewares.for_write, so the decrypting :encryptor never runs
# on the write path. Asserted by standing a recording middleware in for each encryptor key and checking which
# one pg_eventstore invoked - the claim is about the middleware LIST, so no encrypted event class is needed.
RSpec.describe 'Write path middleware selection', integration: true do
  let(:read_encryptor) { RecordingMiddleware.new }
  let(:write_encryptor) { RecordingMiddleware.new }

  around do |example|
    PgEventstore.config.middlewares[Yes::Core::Middlewares::ENCRYPTOR] = read_encryptor
    PgEventstore.config.middlewares[Yes::Core::Middlewares::WRITE_ENCRYPTOR] = write_encryptor
    example.run
  ensure
    PgEventstore.config.middlewares.except!(
      Yes::Core::Middlewares::ENCRYPTOR, Yes::Core::Middlewares::WRITE_ENCRYPTOR
    )
  end

  # write_encryptor.deserialized is expected to be positive: the write variant IS on the list, and it is its
  # #deserialize that does nothing. The load-bearing assertions are the read encryptor's zeros.
  shared_examples 'a write site that skips decryption' do
    it 'appends through the write encryptor and never invokes the decrypting one' do
      subject

      aggregate_failures do
        expect(write_encryptor.serialized).to be_positive
        expect(read_encryptor.serialized).to eq(0)
        expect(read_encryptor.deserialized).to eq(0)
      end
    end
  end

  describe 'EventPublisher, via a single aggregate command' do
    subject { Test::User::Aggregate.new(aggregate_id).change_name(name: 'Jane', user_id: SecureRandom.uuid) }

    let(:aggregate_id) { SecureRandom.uuid }

    before { TestUser.create!(id: aggregate_id, name: 'John') }

    it_behaves_like 'a write site that skips decryption'
  end

  describe 'CommandGroupExecutor, inside client.multiple' do
    subject { Test::PersonalInfo::Aggregate.new(SecureRandom.uuid).update_personal_info_group(**payload) }

    let(:payload) do
      { first_name: 'Ada', last_name: 'Lovelace', email: 'ada@example.com', birth_date: '1815-12-10' }
    end

    it_behaves_like 'a write site that skips decryption'
  end

  describe 'Stateless::Handler' do
    subject { handler_class.new(cmd).call }

    let(:handler_class) do
      Class.new(Yes::Core::Commands::Stateless::Handler).tap { |klass| klass.event_name = 'NameChanged' }
    end
    let(:cmd) { Dummy::Company::Commands::ChangeName::Command.new(name: 'some', company_id: SecureRandom.uuid) }

    it_behaves_like 'a write site that skips decryption'
  end

  describe 'TestSupport::EventHelpers#append_event' do
    include Yes::Core::TestSupport::EventHelpers

    subject { append_event(stream, Yes::Core::Event.new(type: 'Dummy::CompanyNameChanged', data: { 'name' => 'x' })) }

    let(:stream) do
      PgEventstore::Stream.new(context: 'Dummy', stream_name: 'Company', stream_id: SecureRandom.uuid)
    end

    it_behaves_like 'a write site that skips decryption'
  end
end
