# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::PayloadProxy do
  subject(:payload_proxy) do
    described_class.new(
      raw_payload:,
      context:,
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

  let(:context) { 'TestContext' }
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
      end

      it 'resolves aggregate when _id field exists' do
        expect(payload_proxy.user).to eq(user_aggregate)
      end

      it 'tracks the resolved aggregate' do
        payload_proxy.user

        expect(aggregate_tracker).to have_received(:track).with(
          attribute_name: :user,
          id: 'user-123',
          revision: -1,
          context: context
        )
      end

      it 'instantiates aggregate with correct ID' do
        payload_proxy.user
        expect(user_aggregate_class).to have_received(:new).with('user-123')
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
end
