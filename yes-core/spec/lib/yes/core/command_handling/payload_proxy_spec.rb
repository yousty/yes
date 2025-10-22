# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::PayloadProxy do
  subject(:payload_proxy) do
    described_class.new(
      raw_payload:,
      raw_metadata:,
      context:,
      parent_aggregates:,
      aggregate_tracker:
    )
  end

  let(:raw_payload) do
    {
      name: 'Test Name',
      user_id: 'user-123',
      company_id: 'company-456'
    }
  end

  let(:raw_metadata) { nil }
  let(:context) { 'TestContext' }
  let(:parent_aggregates) { {} }
  let(:aggregate_tracker) { instance_double('Yes::Core::CommandHandling::AggregateTracker') }

  describe '#[]' do
    it 'returns value for given key from raw payload' do
      expect(payload_proxy[:name]).to eq('Test Name')
    end

    it 'returns nil for non-existent key' do
      expect(payload_proxy[:non_existent]).to be_nil
    end
  end

  describe 'dynamic method access' do
    context 'when accessing direct payload values' do
      it 'returns the value when key exists' do
        expect(payload_proxy.name).to eq('Test Name')
      end

      it 'raises NoMethodError when key does not exist' do
        expect { payload_proxy.non_existent }.to raise_error(NoMethodError)
      end
    end

    context 'when resolving aggregates' do
      let(:user_aggregate) { instance_double('User::Aggregate', id: 'user-123', revision: -1) }
      let(:user_aggregate_class) { class_double('TestContext::User::Aggregate', new: user_aggregate) }

      before do
        stub_const('TestContext::User::Aggregate', user_aggregate_class)
        allow(aggregate_tracker).to receive(:track)
        allow(user_aggregate).to receive(:reload).and_return(user_aggregate)
      end

      it 'resolves aggregate when _id field exists' do
        expect(payload_proxy.user).to eq(user_aggregate)
      end

      it 'tracks the resolved aggregate' do
        payload_proxy.user

        expect(aggregate_tracker).to have_received(:track).with(
          attribute_name: :user,
          id: 'user-123',
          revision: kind_of(Proc),
          context: context
        )
      end

      it 'instantiates aggregate with correct ID' do
        payload_proxy.user
        expect(user_aggregate_class).to have_received(:new).with('user-123')
      end

      context 'when parent_aggregates specifies different context' do
        let(:parent_aggregates) { { user: { context: 'CustomContext' } } }
        let(:custom_user_aggregate_class) { class_double('CustomContext::User::Aggregate', new: user_aggregate) }

        before do
          stub_const('CustomContext::User::Aggregate', custom_user_aggregate_class)
        end

        it 'uses context from parent_aggregates' do
          payload_proxy.user
          expect(custom_user_aggregate_class).to have_received(:new).with('user-123')
        end

        it 'tracks with custom context' do
          payload_proxy.user

          expect(aggregate_tracker).to have_received(:track).with(
            attribute_name: :user,
            id: 'user-123',
            revision: kind_of(Proc),
            context: 'CustomContext'
          )
        end
      end
    end
  end

  describe '#respond_to?' do
    it 'returns true for existing payload keys' do
      expect(payload_proxy.respond_to?(:name)).to be true
    end

    it 'returns true for existing _id fields' do
      expect(payload_proxy.respond_to?(:user)).to be true
    end

    it 'returns false for non-existent methods' do
      expect(payload_proxy.respond_to?(:non_existent)).to be false
    end
  end

  describe 'string key access (event replay scenario)' do
    subject(:payload_proxy) do
      described_class.new(
        raw_payload: raw_payload_with_string_keys,
        raw_metadata:,
        context:,
        parent_aggregates:,
        aggregate_tracker:
      )
    end

    let(:raw_payload_with_string_keys) do
      {
        'name' => 'Test Name',
        'phone_1' => '',
        'user_id' => 'user-123',
        'company_id' => 'company-456'
      }
    end

    context 'when accessing direct payload values with string keys' do
      it 'returns the value for string key via method access' do
        expect(payload_proxy.name).to eq('Test Name')
      end

      it 'returns empty string for empty value' do
        expect(payload_proxy.phone_1).to eq('')
      end

      it 'raises NoMethodError when key does not exist' do
        expect { payload_proxy.non_existent }.to raise_error(NoMethodError)
      end
    end

    context 'when resolving aggregates with string _id keys' do
      let(:user_aggregate) { instance_double('User::Aggregate', id: 'user-123', revision: -1) }
      let(:user_aggregate_class) { class_double('TestContext::User::Aggregate', new: user_aggregate) }

      before do
        stub_const('TestContext::User::Aggregate', user_aggregate_class)
        allow(aggregate_tracker).to receive(:track)
        allow(user_aggregate).to receive(:reload).and_return(user_aggregate)
      end

      it 'resolves aggregate when _id field exists as string key' do
        expect(payload_proxy.user).to eq(user_aggregate)
      end

      it 'tracks the resolved aggregate' do
        payload_proxy.user

        expect(aggregate_tracker).to have_received(:track).with(
          attribute_name: :user,
          id: 'user-123',
          revision: kind_of(Proc),
          context: context
        )
      end
    end

    describe '#respond_to? with string keys' do
      it 'returns true for existing string key payload fields' do
        expect(payload_proxy.respond_to?(:name)).to be true
      end

      it 'returns true for existing string _id fields' do
        expect(payload_proxy.respond_to?(:user)).to be true
      end

      it 'returns false for non-existent methods' do
        expect(payload_proxy.respond_to?(:non_existent)).to be false
      end
    end
  end

  describe '#metadata' do
    context 'when metadata is nil' do
      let(:raw_metadata) { nil }

      it 'returns a metadata proxy' do
        expect(payload_proxy.metadata).to be_an_instance_of(Yes::Core::CommandHandling::MetadataProxy)
      end

      it 'returns empty hash when accessing non-existent keys' do
        expect(payload_proxy.metadata[:foo]).to be_nil
      end
    end

    context 'when metadata has values' do
      let(:raw_metadata) { { user_agent: 'TestAgent/1.0', request_id: 'req-123' } }

      it 'returns metadata values via hash access' do
        expect(payload_proxy.metadata[:user_agent]).to eq('TestAgent/1.0')
      end

      it 'returns metadata values via method access' do
        expect(payload_proxy.metadata.request_id).to eq('req-123')
      end

      it 'allows setting metadata values via hash access' do
        payload_proxy.metadata[:new_key] = 'new_value'
        expect(payload_proxy.metadata[:new_key]).to eq('new_value')
      end

      it 'allows setting metadata values via method access' do
        payload_proxy.metadata.another_key = 'another_value'
        expect(payload_proxy.metadata.another_key).to eq('another_value')
      end
    end
  end
end
