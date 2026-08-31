# frozen_string_literal: true

RSpec.describe Yes::Core::Authorization::LookupCache do
  let(:key) { :some_key }

  describe '.active?' do
    subject { described_class.active? }

    context 'when no scope is open' do
      it { is_expected.to be(false) }
    end

    context 'when a scope is open' do
      it 'is true inside the scope and false again once it closes' do
        inside = described_class.with_scope { described_class.active? }

        aggregate_failures do
          expect(inside).to be(true)
          expect(described_class.active?).to be(false)
        end
      end
    end
  end

  describe '.fetch' do
    context 'when no scope is open' do
      it 'evaluates the block on every call' do
        calls = 0
        2.times { described_class.fetch(key) { calls += 1 } }

        expect(calls).to eq(2)
      end
    end

    context 'when a scope is open' do
      let(:first_value) { SecureRandom.hex(4) }
      let(:second_value) { SecureRandom.hex(4) }

      it 'evaluates the block once per key and reuses the value' do
        calls = 0
        values = described_class.with_scope do
          Array.new(3) { described_class.fetch(key) { calls += 1 } }
        end

        aggregate_failures do
          expect(calls).to eq(1)
          expect(values).to eq([1, 1, 1])
        end
      end

      it 'caches each key separately' do
        values = described_class.with_scope do
          [
            described_class.fetch(:a) { first_value },
            described_class.fetch(:b) { second_value },
            described_class.fetch(:a) { second_value }
          ]
        end

        expect(values).to eq([first_value, second_value, first_value])
      end

      it 'caches nil results without re-evaluating the block' do
        calls = 0
        values = described_class.with_scope do
          Array.new(2) do
            described_class.fetch(key) do
              calls += 1
              nil
            end
          end
        end

        aggregate_failures do
          expect(calls).to eq(1)
          expect(values).to eq([nil, nil])
        end
      end
    end
  end

  describe '.with_scope' do
    it 'returns the value of the block' do
      expect(described_class.with_scope { 'result' }).to eq('result')
    end

    it 'clears the cache when the scope raises' do
      expect { described_class.with_scope { raise 'boom' } }.to raise_error('boom')
      expect(described_class.active?).to be(false)
    end

    it 'does not leak cached values into a later scope' do
      calls = 0
      2.times { described_class.with_scope { described_class.fetch(key) { calls += 1 } } }

      expect(calls).to eq(2)
    end

    it 'reuses the outer cache for nested scopes' do
      calls = 0
      described_class.with_scope do
        described_class.fetch(key) { calls += 1 }
        described_class.with_scope { described_class.fetch(key) { calls += 1 } }
      end

      expect(calls).to eq(1)
    end

    it 'keeps the cache open for the outer scope after a nested scope closes' do
      still_active = described_class.with_scope do
        described_class.with_scope { nil }
        described_class.active?
      end

      expect(still_active).to be(true)
    end

    it 'isolates the cache per thread' do
      calls = 0
      described_class.with_scope do
        described_class.fetch(key) { calls += 1 }
        Thread.new { described_class.with_scope { described_class.fetch(key) { calls += 1 } } }.join
      end

      expect(calls).to eq(2)
    end
  end
end
