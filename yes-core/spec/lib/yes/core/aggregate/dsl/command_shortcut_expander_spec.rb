# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::CommandShortcutExpander do
  describe '.base_case?' do
    subject { described_class.base_case?(*args, **kwargs, &block) }

    let(:args) { [] }
    let(:kwargs) { {} }
    let(:block) { nil }

    context 'for regular command definiton' do
      let(:args) { [:publish] }
      let(:block) { -> { true } }

      it 'returns true' do
        expect(subject).to eq true
      end
    end

    context 'for change shortcut' do
      let(:args) { %i[change age integer] }
      let(:kwargs) { { localized: true } }

      it 'returns false' do
        expect(subject).to eq false
      end
    end

    context 'for enable shortcut' do
      let(:args) { %i[activate dropout] }
      let(:kwargs) { { attribute: :dropout_enabled } }

      it 'returns false' do
        expect(subject).to eq false
      end
    end

    context 'for toggle shortcut' do
      let(:args) { [%i[enable disable], :dropout] }

      it 'returns false' do
        expect(subject).to eq false
      end
    end

    context 'for publish shortcut' do
      let(:args) { [:publish] }

      it 'returns false' do
        expect(subject).to eq false
      end
    end
  end

  describe '#call' do
    subject { described_class.new(*args, **kwargs, &block).call }

    let(:args) { [] }
    let(:kwargs) { {} }
    let(:block) { nil }

    context 'for change shortcut' do
      let(:args) { %i[change age integer] }
      let(:kwargs) { { localized: true } }

      it 'returns correct attributes' do
        expect(subject.attributes).to match(
          [
            Yes::Core::Aggregate::Dsl::CommandShortcutExpander::AttributeSpecification.new(
              name: :age,
              type: :integer,
              options: { localized: true }
            )
          ]
        )
      end

      it 'returns correct commands' do
        expect(subject.commands.map(&:name)).to match([:change_age])
      end
    end

    context 'for enable shortcut' do
      let(:args) { %i[activate dropout] }
      let(:kwargs) { { attribute: :dropout_enabled } }

      it 'returns correct attributes' do
        expect(subject.attributes).to match(
          [
            Yes::Core::Aggregate::Dsl::CommandShortcutExpander::AttributeSpecification.new(
              name: :dropout_enabled,
              type: :boolean,
              options: {}
            )
          ]
        )
      end

      it 'returns correct commands' do
        expect(subject.commands.map(&:name)).to match([:activate_dropout])
      end
    end

    context 'for toggle shortcut' do
      let(:args) { [%i[enable disable], :dropout] }

      it 'returns correct attributes' do
        expect(subject.attributes).to match(
          [
            Yes::Core::Aggregate::Dsl::CommandShortcutExpander::AttributeSpecification.new(
              name: :dropout,
              type: :boolean,
              options: {}
            )
          ]
        )
      end

      it 'returns correct commands' do
        expect(subject.commands.map(&:name)).to match(%i[enable_dropout disable_dropout])
      end
    end

    context 'for publish shortcut' do
      let(:args) { [:publish] }

      it 'returns correct attributes' do
        expect(subject.attributes).to match(
          [
            Yes::Core::Aggregate::Dsl::CommandShortcutExpander::AttributeSpecification.new(
              name: :published,
              type: :boolean,
              options: {}
            )
          ]
        )
      end

      it 'returns correct commands' do
        expect(subject.commands.map(&:name)).to match(%i[publish])
      end
    end
  end
end
