# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::Helpers::V1 do

  let(:start_application_class) do
    Class.new(Yes::Core::Command) do
      attribute :application_id, Yes::Core::Types::UUID.default { SecureRandom.uuid }
      alias aggregate_id application_id
    end
  end

  before do
    stub_const('DummyJobApplication::Application', Class.new(Yes::Core::Command))
    stub_const('DummyJobApplication::ApplicationState', Class.new(Yes::Core::Command))
    stub_const('DummyJobApplication::V1::Application', Class.new(Yes::Core::Command))
    stub_const('DummyJobApplication::V1::ApplicationState', Class.new(Yes::Core::Command))

    stub_const(
      'DummyJobApplication::Commands::Application::StartApplication',
      start_application_class
    )
    stub_const(
      'DummyJobApplication::Commands::Application::StartApplicationAuthorizer',
      Class.new(Yes::Core::Command)
    )

    stub_const(
      'DummyJobApplication::Commands::V1::Application::StartApplication',
      Class.new(Yes::Core::Command)
    )
    stub_const('DummyJobApplication::Commands::V1::Application::StartApplicationAuthorizer',
      Class.new(Yes::Core::Command)
    )
  end

  describe '#command_name' do
    subject { described_class.new(cmd).command_name }

    context 'when there is no version namespace' do
      let(:cmd) { DummyJobApplication::Commands::Application::StartApplication.new({}) }

      it 'returns proper class name' do
        expect(subject).to eq('start_application')
      end
    end

    context 'when there is a version namespace' do
      let(:cmd) { DummyJobApplication::Commands::V1::Application::StartApplication.new({}) }

      it 'returns proper class name' do
        expect(subject).to eq('start_application')
      end
    end
  end

  describe '#aggregate_classname' do
    subject { described_class.new(cmd).aggregate_classname }

    context 'when there is no version namespace' do
      let(:cmd) { DummyJobApplication::Commands::Application::StartApplication.new({}) }

      it 'returns proper aggregate class name' do
        expect(subject).to eq('Application')
      end
    end

    context 'when there is a version namespace' do
      let(:cmd) { DummyJobApplication::Commands::V1::Application::StartApplication.new({}) }

      it 'returns proper aggregate class name' do
        expect(subject).to eq('Application')
      end
    end
  end

  describe '#aggregate_module' do
    subject { described_class.new(cmd).aggregate_module }

    context 'when there is no version namespace' do
      let(:cmd) { DummyJobApplication::Commands::Application::StartApplication.new({}) }

      it { is_expected.to eq('Application') }
    end

    context 'when there is a version namespace' do
      let(:cmd) { DummyJobApplication::Commands::V1::Application::StartApplication.new({}) }

      it { is_expected.to eq('Application') }
    end
  end

  describe '#authorizer_classname' do
    subject { described_class.new(cmd).authorizer_classname }

    context 'when there is no version namespace' do
      let(:cmd) { DummyJobApplication::Commands::Application::StartApplication.new({}) }

      it 'returns proper authorizer class name' do
        expect(subject).to eq('DummyJobApplication::Commands::Application::StartApplicationAuthorizer')
      end
    end

    context 'when there is a version namespace' do
      let(:cmd) { DummyJobApplication::Commands::V1::Application::StartApplication.new({}) }

      it 'returns proper authorizer class name' do
        expect(subject).to eq('DummyJobApplication::Commands::V1::Application::StartApplicationAuthorizer')
      end
    end
  end

  describe '#validator_classname' do
    subject { described_class.new(cmd).validator_classname }

    context 'when there is no version namespace' do
      let(:cmd) { DummyJobApplication::Commands::Application::StartApplication.new({}) }

      it 'returns proper validator class name' do
        expect(subject).to eq('DummyJobApplication::Commands::Application::StartApplicationValidator')
      end
    end

    context 'when there is a version namespace' do
      let(:cmd) { DummyJobApplication::Commands::V1::Application::StartApplication.new({}) }

      it 'returns proper validator class name' do
        expect(subject).to eq('DummyJobApplication::Commands::V1::Application::StartApplicationValidator')
      end
    end
  end

  describe '#aggregate_class' do
    subject { described_class.new(cmd).aggregate_class }

    context 'when there is no version namespace' do
      let(:cmd) { DummyJobApplication::Commands::Application::StartApplication.new({}) }

      it 'returns proper aggregate class' do
        expect(subject).to eq(DummyJobApplication::Application)
      end
    end

    context 'when there is a version namespace' do
      let(:cmd) { DummyJobApplication::Commands::V1::Application::StartApplication.new({}) }

      it 'returns proper aggregate class' do
        expect(subject).to eq(DummyJobApplication::V1::Application)
      end
    end
  end


  describe '#subject_id' do
    subject { described_class.new(cmd).subject_id }

    let(:subject_id) { SecureRandom.uuid }

    let(:cmd) do
      DummyJobApplication::Commands::Application::StartApplication.new(application_id: subject_id)
    end

    it 'returns proper subject id' do
      expect(subject).to eq(subject_id)
    end
  end
end
