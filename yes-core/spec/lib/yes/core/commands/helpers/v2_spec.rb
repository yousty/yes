# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::Helpers::V2 do
  let(:command_class) do
    Class.new(Yes::Core::Command) do
      attribute :company_id, Yes::Core::Types::UUID.default { SecureRandom.uuid }
      attribute :apprenticeship_id, Yes::Core::Types::UUID.default { SecureRandom.uuid }
      alias subject_id apprenticeship_id
    end
  end

  before do
    stub_const(
      'DummyApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Command',
      command_class
    )
    stub_const(
      'DummyApprenticeshipPresentation::Apprenticeship::Aggregate',
      Class.new
    )
  end

  let(:cmd) { DummyApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Command.new({}) }

  describe '#command_name' do
    subject { described_class.new(cmd).command_name }

    it 'returns proper class name' do
      expect(subject).to eq('assign_company')
    end
  end

  describe '#aggregate_module' do
    subject { described_class.new(cmd).aggregate_module }

    it 'returns proper aggregate module' do
      expect(subject).to eq('Apprenticeship')
    end
  end

  describe '#aggregate_classname' do
    subject { described_class.new(cmd).aggregate_classname }

    it 'returns proper aggregate module' do
      expect(subject).to eq('Aggregate')
    end
  end

  describe '#authorizer_classname' do
    subject { described_class.new(cmd).authorizer_classname }

    let(:name) { 'DummyApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Authorizer' }

    it 'returns proper authorizer class name' do
      expect(subject).to eq(name)
    end
  end

  describe '#validator_classname' do
    subject { described_class.new(cmd).validator_classname }

    let(:name) { 'DummyApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Validator' }

    it 'returns proper validator class name' do
      expect(subject).to eq(name)
    end
  end

  describe '#aggregate_class' do
    subject { described_class.new(cmd).aggregate_class }

    before do
      stub_const(
        'DummyApprenticeshipPresentation::Apprenticeship::Aggregate',
        Class.new(Yes::Core::Aggregate)
      )
    end

    it 'returns proper validator class name' do
      expect(subject).to eq(DummyApprenticeshipPresentation::Apprenticeship::Aggregate)
    end
  end

  describe '#subject_id' do
    subject { described_class.new(cmd).subject_id }

    let(:subject_id) { SecureRandom.uuid }

    let(:cmd) do
      DummyApprenticeshipPresentation::Apprenticeship::Commands::AssignCompany::Command.new(
        apprenticeship_id: subject_id,
        company_id: SecureRandom.uuid
      )
    end

    it 'returns proper subject id' do
      expect(subject).to eq(subject_id)
    end
  end
end
