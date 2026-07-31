# frozen_string_literal: true

RSpec.describe Yes::Core::Middlewares do
  let(:key_repository) { DummyRepository.new }
  let(:base_keys) { %i[with_indifferent_access timestamp] }

  after { PgEventstore.config.middlewares.except!(described_class::ENCRYPTOR, described_class::WRITE_ENCRYPTOR) }

  describe '.register_encryptor' do
    subject { described_class.register_encryptor(key_repository) }

    it 'registers both variants after the order-sensitive middlewares' do
      subject

      expect(PgEventstore.config.middlewares.keys).to eq(base_keys + %i[encryptor write_encryptor])
    end

    it 'registers the right class under each key' do
      subject

      aggregate_failures do
        expect(PgEventstore.config.middlewares[described_class::ENCRYPTOR]).
          to be_an_instance_of(described_class::Encryptor)
        expect(PgEventstore.config.middlewares[described_class::WRITE_ENCRYPTOR]).
          to be_an_instance_of(described_class::WriteEncryptor)
      end
    end
  end

  describe '.for_write' do
    subject { described_class.for_write }

    context 'when both encryptor variants are registered' do
      before { described_class.register_encryptor(key_repository) }

      it { is_expected.to eq(base_keys + [described_class::WRITE_ENCRYPTOR]) }
    end

    # A list that dropped :encryptor here would write plaintext at rest, so the fallback keeps it.
    context 'when only the decrypting encryptor is registered' do
      before do
        described_class.register_encryptor(key_repository)
        PgEventstore.config.middlewares.delete(described_class::WRITE_ENCRYPTOR)
      end

      it { is_expected.to eq(base_keys + [described_class::ENCRYPTOR]) }
    end

    context 'when no encryptor is registered' do
      it { is_expected.to eq(base_keys) }
    end
  end

  describe '.without' do
    subject { described_class.without(described_class::ENCRYPTOR) }

    before { described_class.register_encryptor(key_repository) }

    # Still means "read the data as stored": WriteEncryptor#deserialize is a no-op.
    it { is_expected.to eq(base_keys + [described_class::WRITE_ENCRYPTOR]) }
  end
end
