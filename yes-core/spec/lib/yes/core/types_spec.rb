# frozen_string_literal: true

RSpec.describe Yes::Core::Types do
  describe 'UUID type' do
    subject(:valid?) { described_class::UUID.valid?(uuid) }

    context 'when given a UUIDv4' do
      let(:uuid) { 'f47ac10b-58cc-4372-a567-0e02b2c3d479' }

      it { is_expected.to be(true) }
    end

    # pg_eventstore 3.0.0 generates event ids with SecureRandom.uuid_v7, and those ids
    # reach us as causation_id. A v4-only constraint killed subscriptions in production.
    context 'when given a UUIDv7' do
      let(:uuid) { '01a027eb-f0b4-7464-b42a-e89a79b0721b' }

      it { is_expected.to be(true) }
    end

    context 'when given a string that is not a UUID' do
      let(:uuid) { 'not-a-uuid' }

      it { is_expected.to be(false) }
    end

    # Still a real constraint: the variant nibble must be 8, 9, a or b.
    context 'when given a UUID-shaped string with an invalid variant' do
      let(:uuid) { 'f47ac10b-58cc-4372-1567-0e02b2c3d479' }

      it { is_expected.to be(false) }
    end

    context 'when given a UUID with an invalid version' do
      let(:uuid) { 'f47ac10b-58cc-0372-a567-0e02b2c3d479' }

      it { is_expected.to be(false) }
    end
  end

  describe 'YEAR_DATE_HASH type' do
    shared_examples 'invalid hash' do
      it 'does not pass the validation' do
        expect(described_class::YEAR_DATE_HASH.valid?(hash)).to be_falsey
      end
    end

    shared_examples 'valid hash' do
      it 'pass the validation' do
        expect(described_class::YEAR_DATE_HASH.valid?(hash)).to be_truthy
      end
    end

    context 'when given has is blank' do
      let(:hash) { {} }

      it_behaves_like 'invalid hash'
    end

    context 'when given a valid hash' do
      let(:hash) do
        {
          '2024' => '2023-09-10',
          '2025' => '2024-12-11',
          2026 => '2025-11-10'
        }
      end

      it_behaves_like 'valid hash'
    end

    context 'when given an invalid hash' do
      context 'when the hash has at leas one wrong key' do
        context 'when key contains underscores' do
          let(:hash) do
            {
              '2_0_2_4' => '2023-09-10',
              '2025' => '2024-12-11'
            }
          end

          it_behaves_like 'invalid hash'
        end

        context 'when key contains letters' do
          let(:hash) do
            {
              '2024A' => '2023-09-10',
              '2025' => '2024-12-11'
            }
          end
        end
      end

      context 'when the hash has wrong date value' do
        context 'when date is not in the correct format' do
          let(:hash) do
            {
              '2024' => '2023/09/10',
              '2025' => '2024-12-11'
            }
          end

          it_behaves_like 'invalid hash'
        end
      end
    end
  end
end
