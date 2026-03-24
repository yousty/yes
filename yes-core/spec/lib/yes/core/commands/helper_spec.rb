# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::Helper do
  let(:apprenticeship_id) { SecureRandom.uuid }
  let(:company_id) { SecureRandom.uuid }

  let(:assign_company_command_class) do
    Class.new(Yes::Core::Command) do
      attribute(:company_id, Yes::Core::Types::UUID.default { SecureRandom.uuid })
      attribute(:apprenticeship_id, Yes::Core::Types::UUID.default { SecureRandom.uuid })
      attribute :locale, Yes::Core::Types::Strict::String.default('de-CH')
      alias aggregate_id apprenticeship_id
    end
  end

  let(:cmd) do
    DummyApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Command.new(
      apprenticeship_id:,
      company_id:,
      transaction: Yes::Core::TransactionDetails.new,
      origin: 'some origin'
    )
  end

  let(:cmd_versioned) do
    DummyApprenticeshipPresentation::Apprenticeship::Commands::V11::AssignCompany::Command.new({})
  end

  before do
    stub_const(
      'DummyApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Command',
      assign_company_command_class
    )

    stub_const(
      'DummyApprenticeshipPresentation::Apprenticeship::Aggregate',
      Class.new(Yes::Core::Aggregate)
    )

    stub_const(
      'DummyApprenticeshipPresentation::Apprenticeship::Commands::V11::AssignCompany::Command',
      Class.new(Yes::Core::Command)
    )
  end

  describe '#command_context' do
    subject { described_class.new(cmd).command_context }

    it { is_expected.to eq('DummyApprenticeshipPresentation') }
  end

  describe '#command_locale' do
    subject { described_class.new(cmd).command_locale }

    context 'when command does not support locale' do
      it 'returns default locale' do
        expect(subject).to eq('de-CH')
      end
    end
  end

  describe '#command_version' do
    subject { described_class.new(cmd).command_version }

    context 'when command is not versioned' do
      it { is_expected.to be_nil }
    end

    context 'when command is versioned' do
      let(:cmd) { cmd_versioned }

      it { is_expected.to eq('V11') }
    end
  end

  describe '#event_payload' do
    subject { described_class.new(cmd).event_payload }

    it 'returns proper attributes' do
      expect(subject).to include(
        {
          'locale' => 'de-CH',
          'apprenticeship_id' => apprenticeship_id,
          'company_id' => company_id
        }
      )
    end

    it 'does not include transaction and origin' do
      expect(subject.slice('transaction', 'origin')).to be_empty
    end
  end

  describe '#command_name' do
    subject { described_class.new(cmd).command_name }

    it { is_expected.to eq('assign_company') }
  end

  describe '#aggregate_classname' do
    subject { described_class.new(cmd).aggregate_classname }

    it { is_expected.to eq('Aggregate') }
  end

  describe '#aggregate_module' do
    subject { described_class.new(cmd).aggregate_module }

    it { is_expected.to eq('Apprenticeship') }
  end

  describe '#authorizer_classname' do
    subject { described_class.new(cmd).authorizer_classname }

    it { is_expected.to eq('DummyApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Authorizer') }
  end

  describe '#validator_classname' do
    subject { described_class.new(cmd).validator_classname }

    it { is_expected.to eq('DummyApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Validator') }
  end

  describe '#aggregate_class' do
    subject { described_class.new(cmd).aggregate_class }

    it { is_expected.to eq(DummyApprenticeshipPresentation::Apprenticeship::Aggregate) }
  end

  describe '#aggregate_id' do
    subject { described_class.new(cmd).aggregate_id }

    it { is_expected.to eq(apprenticeship_id) }
  end
end
