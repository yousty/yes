# frozen_string_literal: true

RSpec.describe Yes::Core::Utils::HashUtils do
  describe '.deep_flatten_hash' do
    subject(:flattened) { described_class.deep_flatten_hash(obj, prefix) }

    context 'with a flat hash and no prefix' do
      let(:prefix) { nil }
      let(:obj) { { name: 'A', count: 2 } }

      it 'stringifies the keys' do
        expect(flattened).to eq('name' => 'A', 'count' => 2)
      end
    end

    context 'with nested hashes' do
      let(:prefix) { nil }
      let(:obj) { { name: 'A', otl_contexts: { root: { attr: 10, available: true } } } }

      it 'joins nested keys with dots' do
        expect(flattened).to eq(
          'name' => 'A',
          'otl_contexts.root.attr' => 10,
          'otl_contexts.root.available' => true
        )
      end
    end

    context 'with a prefix' do
      let(:prefix) { 'span' }
      let(:obj) { { id: 1, nested: { a: 2 } } }

      it 'prefixes scalar and nested-hash keys' do
        expect(flattened).to eq('span.id' => 1, 'span.nested.a' => 2)
      end
    end

    context 'with an array value and a prefix' do
      let(:prefix) { 'span' }
      let(:obj) { { id: 1, tags: [{ k: 'v' }] } }

      it 'prefixes the array key too (regression: the prefix was previously dropped)' do
        expect(flattened).to eq('span.id' => 1, 'span.tags' => [{ 'k' => 'v' }])
      end
    end

    context 'with an array value and no prefix' do
      let(:prefix) { nil }
      let(:obj) { { tags: [{ k: 'v' }] } }

      it 'keys the array by its stringified name' do
        expect(flattened).to eq('tags' => [{ 'k' => 'v' }])
      end
    end
  end

  describe '.deep_dup' do
    subject(:duplicate) { described_class.deep_dup(original) }

    let(:original) { { a: { b: 1 } } }

    it 'returns an independent deep copy' do
      duplicate[:a][:b] = 99

      expect(original[:a][:b]).to eq(1)
    end
  end
end
