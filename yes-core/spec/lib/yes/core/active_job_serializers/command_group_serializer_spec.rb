# frozen_string_literal: true

RSpec.describe Yes::Core::ActiveJobSerializers::CommandGroupSerializer do
  subject(:serializer) { described_class.instance }

  let(:personal_info_id) { SecureRandom.uuid }
  let(:full_group_payload) do
    {
      personal_info_id: personal_info_id,
      first_name: 'Ada',
      last_name: 'Lovelace',
      email: 'ada@example.com',
      birth_date: '1815-12-10'
    }
  end
  let(:aggregate_dsl_group) do
    Test::PersonalInfo::CommandGroups::UpdatePersonalInfoGroup::Command.new(full_group_payload)
  end

  describe '#serialize?' do
    it 'matches aggregate-DSL Yes::Core::Commands::CommandGroup instances' do
      expect(serializer.serialize?(aggregate_dsl_group)).to be(true)
    end

    it 'matches legacy Yes::Core::Commands::Group instances' do
      # spec/support/v2/dummy_commands.rb registers Dummy::Company::Commands::DoSomethingCompounded
      # as a Yes::Core::Commands::Group subclass.
      legacy = Dummy::Company::Commands::DoSomethingCompounded::Command.new(
        company: { company_id: SecureRandom.uuid, name: 'Acme', description: 'best' },
        user: { user_id: SecureRandom.uuid, first_name: 'Ada', last_name: 'Lovelace' }
      )
      expect(serializer.serialize?(legacy)).to be(true)
    end

    it 'does not match regular Yes::Core::Command instances' do
      regular = Test::PersonalInfo::Commands::ChangeName::Command.new(
        personal_info_id: personal_info_id,
        first_name: 'Ada',
        last_name: 'Lovelace'
      )
      expect(serializer.serialize?(regular)).to be(false)
    end
  end

  describe '#serialize and #deserialize round-trip for aggregate-DSL CommandGroup' do
    let(:batch_id) { SecureRandom.uuid }
    let(:cmd) do
      Test::PersonalInfo::CommandGroups::UpdatePersonalInfoGroup::Command.new(
        full_group_payload.merge(origin: 'cli', batch_id: batch_id)
      )
    end

    subject(:round_tripped) do
      serialized = serializer.serialize(cmd)
      serializer.deserialize(serialized)
    end

    it 'returns an instance of the original class' do
      expect(round_tripped).to be_a(Test::PersonalInfo::CommandGroups::UpdatePersonalInfoGroup::Command)
    end

    it 'preserves the flat payload (after symbol/string key normalization)' do
      expect(round_tripped.payload).to eq(cmd.payload)
    end

    it 'preserves the reserved keys (origin, batch_id, command_id)' do
      aggregate_failures do
        expect(round_tripped.origin).to eq(cmd.origin)
        expect(round_tripped.batch_id).to eq(cmd.batch_id)
        expect(round_tripped.command_id).to eq(cmd.command_id)
      end
    end

    it 'rebuilds the same set of sub-commands' do
      expect(round_tripped.commands.map(&:class)).to eq(cmd.commands.map(&:class))
    end
  end
end
