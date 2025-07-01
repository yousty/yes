# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::MetadataProxy do
  subject(:metadata_proxy) { described_class.new(raw_metadata) }

  let(:raw_metadata) { {} }

  describe '#initialize' do
    context 'when metadata is nil' do
      let(:raw_metadata) { nil }

      it 'initializes with empty hash' do
        expect { metadata_proxy }.not_to raise_error
      end
    end
  end

  describe '#[]' do
    context 'when metadata has values' do
      let(:raw_metadata) { { user_agent: 'TestAgent/1.0', request_id: 'req-123' } }

      it 'returns value for existing key' do
        expect(metadata_proxy[:user_agent]).to eq('TestAgent/1.0')
      end

      it 'returns nil for non-existent key' do
        expect(metadata_proxy[:non_existent]).to be_nil
      end
    end

    context 'when metadata is empty' do
      it 'returns nil for any key' do
        expect(metadata_proxy[:any_key]).to be_nil
      end
    end
  end

  describe '#[]=' do
    it 'sets value for key' do
      metadata_proxy[:new_key] = 'new_value'
      expect(metadata_proxy[:new_key]).to eq('new_value')
    end

    it 'overwrites existing value' do
      metadata_proxy[:key] = 'old_value'
      metadata_proxy[:key] = 'new_value'
      expect(metadata_proxy[:key]).to eq('new_value')
    end
  end

  describe 'method access' do
    context 'when accessing existing values' do
      let(:raw_metadata) { { user_agent: 'TestAgent/1.0', 'request_id' => 'req-123' } }

      it 'returns value for symbol key via method' do
        expect(metadata_proxy.user_agent).to eq('TestAgent/1.0')
      end

      it 'returns value for string key via method' do
        expect(metadata_proxy.request_id).to eq('req-123')
      end

      it 'returns nil for non-existent method' do
        expect(metadata_proxy.non_existent).to be_nil
      end
    end

    context 'when setting values' do
      it 'sets value via setter method' do
        metadata_proxy.new_key = 'new_value'
        expect(metadata_proxy.new_key).to eq('new_value')
      end

      it 'can access value set via setter using hash access' do
        metadata_proxy.some_key = 'some_value'
        expect(metadata_proxy[:some_key]).to eq('some_value')
      end

      it 'can access value set via hash using method access' do
        metadata_proxy[:another_key] = 'another_value'
        expect(metadata_proxy.another_key).to eq('another_value')
      end
    end
  end

  describe '#respond_to_missing?' do
    let(:raw_metadata) { { user_agent: 'TestAgent/1.0' } }

    it 'returns true for existing keys' do
      expect(metadata_proxy.respond_to?(:user_agent)).to be true
    end

    it 'returns true for setter methods' do
      expect(metadata_proxy.respond_to?(:new_key=)).to be true
    end

    it 'returns false for non-existent getter when key does not exist' do
      expect(metadata_proxy.respond_to?(:non_existent)).to be false
    end

    it 'returns true for string keys' do
      metadata_proxy['string_key'] = 'value'
      expect(metadata_proxy.respond_to?(:string_key)).to be true
    end
  end

  describe 'method_missing behavior' do
    it 'raises NoMethodError for methods with arguments' do
      expect { metadata_proxy.some_method('arg') }.to raise_error(NoMethodError)
    end

    it 'handles complex method names' do
      metadata_proxy.complex_method_name = 'complex_value'
      expect(metadata_proxy.complex_method_name).to eq('complex_value')
    end

    it 'handles methods ending with special characters' do
      expect(metadata_proxy.enabled?).to be_nil
      metadata_proxy[:enabled?] = true
      expect(metadata_proxy.enabled?).to be true
    end
  end

  describe 'edge cases' do
    context 'when metadata contains nil values' do
      let(:raw_metadata) { { key_with_nil: nil } }

      it 'returns nil for nil values' do
        expect(metadata_proxy.key_with_nil).to be_nil
      end

      it 'distinguishes between nil value and missing key' do
        expect(metadata_proxy[:key_with_nil]).to be_nil
        expect(metadata_proxy[:missing_key]).to be_nil
      end
    end

    context 'when metadata contains complex values' do
      let(:raw_metadata) do
        {
          array_value: [1, 2, 3],
          hash_value: { nested: 'value' },
          boolean_value: true
        }
      end

      it 'returns array values' do
        expect(metadata_proxy.array_value).to eq([1, 2, 3])
      end

      it 'returns hash values' do
        expect(metadata_proxy.hash_value).to eq({ nested: 'value' })
      end

      it 'returns boolean values' do
        expect(metadata_proxy.boolean_value).to be true
      end
    end
  end
end