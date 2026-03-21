# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::Helper do
  let(:cmd_helpers_v2_class) { Yes::Core::Commands::Helpers::V2 }
  let(:cmd_helpers_v1_class) { Yes::Core::Commands::Helpers::V1 }

  let(:cmd_helpers_instance_v2) { instance_spy(cmd_helpers_v2_class) }
  let(:cmd_helpers_instance_v1) { instance_spy(cmd_helpers_v1_class) }

  let(:helper) { :command_name }

  let(:apprenticeship_id) { SecureRandom.uuid }
  let(:company_id) { SecureRandom.uuid }
  let(:application_id) { SecureRandom.uuid }
  let(:command_locale) { 'fr-CH' }

  let(:start_application_command_class) do
    Class.new(Yes::Core::Command) do
      attribute :application_id, Yes::Core::Types::UUID.default { SecureRandom.uuid }
      attribute :locale, Yes::Core::Types::Strict::String.default('de-CH')
    end
  end

  let(:start_application_v1_command_class) do
    Class.new(Yes::Core::Command) do
      attribute :application_id, Yes::Core::Types::UUID.default { SecureRandom.uuid }
      attribute :locale, Yes::Core::Types::Strict::String.default('de-CH')
    end
  end

  let(:assign_company_command_class) do
    Class.new(Yes::Core::Command) do
      attribute :company_id, Yes::Core::Types::UUID.default { SecureRandom.uuid }
      attribute :apprenticeship_id, Yes::Core::Types::UUID.default { SecureRandom.uuid }
      attribute :locale, Yes::Core::Types::Strict::String.default('de-CH')
    end
  end

  let(:cmd_v1) do
    DummyJobApplication::Commands::Application::StartApplication.new(
      application_id:,
      transaction: Yes::Core::TransactionDetails.new,
      origin: 'some origin',
      locale: command_locale,
      metadata: { foo: :bar }
    )
  end
  let(:cmd_v1_versioned) do
    DummyJobApplication::Commands::V1::Application::StartApplication.new(
      locale: command_locale
    )
  end
  let(:cmd_v2) do
    DummyApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Command.new(
      apprenticeship_id:,
      company_id:,
      transaction: Yes::Core::TransactionDetails.new,
      origin: 'some origin'
    )
  end
  let(:cmd_v2_versioned) do
    DummyApprenticeshipPresentation::Apprenticeship::Commands::V11::AssignCompany::Command.new({})
  end

  before do
    stub_const('DummyJobApplication::Application', Class.new(Yes::Core::Command))
    stub_const('DummyJobApplication::ApplicationState', Class.new(Yes::Core::Command))
    stub_const('DummyJobApplication::V1::Application', Class.new(Yes::Core::Command))
    stub_const('DummyJobApplication::V1::ApplicationState', Class.new(Yes::Core::Command))

    stub_const(
      'DummyJobApplication::Commands::Application::StartApplication',
      start_application_command_class
    )
    stub_const(
      'DummyJobApplication::Commands::V1::Application::StartApplication',
      start_application_v1_command_class
    )

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

    allow(cmd_helpers_instance_v2).to receive(helper)
    allow(cmd_helpers_instance_v1).to receive(helper)
  end

  shared_examples 'calls correct helper' do
    before do
      allow(cmd_helpers_v2_class).to receive(:new).with(cmd).and_return(cmd_helpers_instance_v2)
      allow(cmd_helpers_v1_class).to receive(:new).with(cmd).and_return(cmd_helpers_instance_v1)
    end

    context 'when V1 structure' do
      let(:cmd) { cmd_v1 }

      it 'calls correct version helper' do
        subject

        aggregate_failures do
          expect(cmd_helpers_instance_v1).to have_received(helper)
          expect(cmd_helpers_instance_v2).to_not have_received(helper)
        end
      end
    end

    context 'when V2 structure' do
      let(:cmd) { cmd_v2 }

      it 'calls correct version helper' do
        subject

        aggregate_failures do
          expect(cmd_helpers_instance_v2).to have_received(helper)
          expect(cmd_helpers_instance_v1).to_not have_received(helper)
        end
      end
    end
  end

  describe '#command_context' do
    subject { described_class.new(cmd).command_context }

    context 'when V1 structure' do
      let(:cmd) { cmd_v1 }
      let(:command_context) { 'DummyJobApplication' }

      it { is_expected.to eq(command_context) }

      context 'when command is versioned' do
        let(:cmd) { cmd_v1_versioned }

        it { is_expected.to eq(command_context) }
      end
    end

    context 'when V2 structure' do
      let(:cmd) { cmd_v2 }

      it { is_expected.to eq('DummyApprenticeshipPresentation') }
    end
  end

  describe '#command_locale' do
    subject { described_class.new(cmd).command_locale }

    context 'when V1 structure' do
      let(:cmd) { cmd_v1 }
      let(:command_locale) { 'fr-CH' }

      it { is_expected.to eq(command_locale) }

      context 'when command is versioned' do
        let(:cmd) { cmd_v1_versioned }

        it { is_expected.to eq(command_locale) }
      end
    end

    context 'when V2 structure' do
      let(:cmd) { cmd_v2 }

      context 'when command does not supports locale' do
        it 'returns default locale' do
          expect(subject).to eq('de-CH')
        end
      end
    end
  end

  describe '#command_version' do
    subject { described_class.new(cmd).command_version }

    context 'when V1 structure' do
      let(:cmd) { cmd_v1 }

      context 'when command is not versioned' do
        it { is_expected.to eq(nil) }
      end

      context 'when command is versioned' do
        let(:cmd) { cmd_v1_versioned }

        it { is_expected.to eq('V1') }
      end
    end

    context 'when V2 structure' do
      let(:cmd) { cmd_v2 }

      context 'when command is not versioned' do
        it { is_expected.to eq(nil) }
      end

      context 'when command is versioned' do
        let(:cmd) { cmd_v2_versioned }

        it { is_expected.to eq('V11') }
      end
    end
  end

  describe '#event_payload' do
    subject { described_class.new(cmd).event_payload }

    context 'when V1 structure' do
      let(:cmd) { cmd_v1 }

      it 'returns proper event payload' do
        expect(subject).to(
          include("locale" => 'fr-CH', "application_id" => application_id)
        )
      end

      it 'does not include transaction and origin' do
        expect(subject.slice('transaction', 'origin')).to be_empty
      end
    end

    context 'when V2 structure' do
      let(:cmd) { cmd_v2 }

      it 'returns proper attributes' do
        expect(subject).to include(
          {
            "locale" => 'de-CH',
            "apprenticeship_id" => apprenticeship_id,
            "company_id" => company_id
          }
        )
      end

      it 'does not include transaction and origin' do
        expect(subject.slice('transaction', 'origin')).to be_empty
      end
    end
  end

  describe '#command_name' do
    subject { described_class.new(cmd).command_name }

    let(:helper) { :command_name }

    it_behaves_like 'calls correct helper'
  end

  describe '#aggregate_classname' do
    subject { described_class.new(cmd).aggregate_classname }

    let(:helper) { :aggregate_classname }

    it_behaves_like 'calls correct helper'
  end

  describe '#aggregate_module' do
    subject { described_class.new(cmd).aggregate_module }

    let(:helper) { :aggregate_module }

    it_behaves_like 'calls correct helper'
  end

  describe '#authorizer_classname' do
    subject { described_class.new(cmd).authorizer_classname }

    let(:helper) { :authorizer_classname }

    it_behaves_like 'calls correct helper'
  end

  describe '#validator_classname' do
    subject { described_class.new(cmd).validator_classname }

    let(:helper) { :validator_classname }

    it_behaves_like 'calls correct helper'
  end

  describe '#aggregate_class' do
    subject { described_class.new(cmd).aggregate_class }

    let(:helper) { :aggregate_class }

    it_behaves_like 'calls correct helper'
  end
end
