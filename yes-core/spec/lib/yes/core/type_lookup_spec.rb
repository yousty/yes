# frozen_string_literal: true

RSpec.describe Yes::Core::TypeLookup do
  describe '.type_for' do
    subject { described_class.type_for(type, context) }

    let(:context) { 'Test' }

    context 'with :string type' do
      let(:type) { :string }

      it { is_expected.to eq(Yes::Core::Types::Coercible::String) }
    end

    context 'with :integer type' do
      let(:type) { :integer }

      it { is_expected.to eq(Yes::Core::Types::Coercible::Integer) }
    end

    context 'with :boolean type' do
      let(:type) { :boolean }

      it { is_expected.to eq(Yes::Core::Types::Strict::Bool) }
    end

    context 'with :float type' do
      let(:type) { :float }

      it { is_expected.to eq(Yes::Core::Types::Coercible::Float) }
    end

    context 'with :uuid type' do
      let(:type) { :uuid }

      it { is_expected.to eq(Yes::Core::Types::UUID) }
    end

    context 'with :uuids type' do
      let(:type) { :uuids }

      it { is_expected.to eq(Yes::Core::Types::UUIDS) }
    end

    context 'with :email type' do
      let(:type) { :email }

      it { is_expected.to eq(Yes::Core::Types::EMAIL) }
    end

    context 'with :url type' do
      let(:type) { :url }

      it { is_expected.to eq(Yes::Core::Types::URL) }
    end

    context 'with :hash type' do
      let(:type) { :hash }

      it { is_expected.to eq(Yes::Core::Types::Hash) }
    end

    context 'with :locale type' do
      let(:type) { :locale }

      it { is_expected.to eq(Yes::Core::Types::LOCALE) }
    end

    context 'with :array type' do
      let(:type) { :array }

      it { is_expected.to eq(Yes::Core::Types::Array) }
    end

    context 'with :lat type' do
      let(:type) { :lat }

      it { is_expected.to eq(Yes::Core::Types::Coercible::Float) }
    end

    context 'with :lat type for event' do
      subject { described_class.type_for(:lat, context, :event) }

      it { is_expected.to eq(:float) }
    end

    context 'with unknown type' do
      let(:type) { :nonexistent_type_xyz }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, /Unknown type/)
      end
    end

    context 'with context-specific type' do
      let(:type) { :custom }

      before do
        stub_const('Test::Types::CUSTOM', Yes::Core::Types::Coercible::String)
      end

      it 'resolves from context types' do
        expect(subject).to eq(Yes::Core::Types::Coercible::String)
      end
    end
  end
end
