# frozen_string_literal: true

RSpec.describe Yes::Core::Error do
  subject(:error) { described_class.new('boom', **options) }

  let(:options) { {} }

  it { is_expected.to be_a(StandardError) }

  describe '#message' do
    subject { error.message }

    it { is_expected.to eq('boom') }
  end

  # #extra is documented as returning the caller's object untouched, and consumers rely on that
  # by type-checking it themselves. These examples pin the contract so it cannot start coercing
  # (to {} or anything else) without the change being deliberate.
  describe '#extra' do
    subject { error.extra }

    context 'when no extra is given' do
      it { is_expected.to be_nil }
    end

    context 'when a Hash is given' do
      let(:options) { { extra: { id: '9a5b1b3a-0f0c-4a1e-9e2f-6d3c1a7b8e4d' } } }

      it { is_expected.to eq(options[:extra]) }
    end

    context 'when a non-Hash is given' do
      let(:options) { { extra: 'some context' } }

      it 'returns it unchanged rather than coercing it' do
        is_expected.to eq('some context')
      end
    end
  end
end
