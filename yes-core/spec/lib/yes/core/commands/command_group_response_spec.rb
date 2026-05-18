# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::CommandGroupResponse do
  let(:test_group_class) do
    Class.new(Yes::Core::Commands::CommandGroup).tap do |klass|
      klass.context = 'Test'
      klass.aggregate = 'PersonalInfo'
      klass.group_name = :update_all
      klass.sub_command_names = %i[change_name change_email]
    end
  end

  let(:cmd) do
    test_group_class.new(
      personal_info_id: SecureRandom.uuid,
      first_name: 'Ada',
      last_name: 'Lovelace',
      email: 'ada@example.com',
      origin: 'cli',
      batch_id: SecureRandom.uuid
    )
  end

  let(:events) { [] }
  let(:error) { nil }

  subject(:response) { described_class.new(cmd:, events:, error:) }

  describe '#success?' do
    subject { response.success? }

    context 'without error' do
      it { is_expected.to be(true) }
    end

    context 'with error' do
      let(:error) { Yes::Core::CommandHandling::GuardEvaluator::TransitionError.new }

      it { is_expected.to be(false) }
    end
  end

  describe '#error_details' do
    subject { response.error_details }

    context 'without error' do
      it { is_expected.to eq({}) }
    end

    context 'with error carrying extras' do
      let(:error) do
        Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition.new(
          'No company',
          extra: { reason: :missing_company }
        )
      end

      it 'includes message, type and extra' do
        expect(subject).to eq(
          message: 'No company',
          type: 'no_company',
          extra: { reason: :missing_company }
        )
      end
    end
  end

  describe '#type' do
    subject { response.type }

    context 'success' do
      it { is_expected.to eq('command_success') }
    end

    context 'error' do
      let(:error) { Yes::Core::CommandHandling::GuardEvaluator::TransitionError.new }

      it { is_expected.to eq('command_error') }
    end
  end

  describe '#events' do
    it 'defaults to an empty array' do
      response = described_class.new(cmd:)
      expect(response.events).to eq([])
    end

    it 'accepts an array of published events' do
      stream = PgEventstore::Stream.new(context: 'Test', stream_name: 'PersonalInfo', stream_id: cmd.aggregate_id)
      event = PgEventstore::Event.new(type: 'Test::PersonalInfoNameChanged', data: {}, stream: stream)
      response = described_class.new(cmd:, events: [event])
      expect(response.events).to eq([event])
    end
  end

  describe 'delegations' do
    it 'delegates transaction, batch_id, payload, metadata to cmd' do
      expect(response.batch_id).to eq(cmd.batch_id)
      expect(response.payload).to eq(cmd.payload)
      expect(response.metadata).to eq(cmd.metadata)
      expect(response.transaction).to eq(cmd.transaction)
    end
  end
end
