# frozen_string_literal: true

RSpec.describe Yes::Core::Types do
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
          "2024" => "2023-09-10",
          "2025" => "2024-12-11",
          2026 => "2025-11-10"
        }
      end

      it_behaves_like 'valid hash'
    end

    context 'when given an invalid hash' do
      context 'when the hash has at leas one wrong key' do
        context 'when key contains underscores' do
          let(:hash) do
            {
              "2_0_2_4" => "2023-09-10",
              "2025" => "2024-12-11"
            }
          end

          it_behaves_like 'invalid hash'
        end

        context 'when key contains letters' do
          let(:hash) do
            {
              "2024A" => "2023-09-10",
              "2025" => "2024-12-11"
            }
          end
        end
      end

      context 'when the hash has wrong date value' do
        context 'when date is not in the correct format' do
          let(:hash) do
            {
              "2024" => "2023/09/10",
              "2025" => "2024-12-11"
            }
          end

          it_behaves_like 'invalid hash'
        end
      end
    end
  end
end
