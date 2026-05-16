# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::CommandGroup do
  let(:test_group_class) do
    Class.new(described_class).tap do |klass|
      klass.context = 'Test'
      klass.aggregate = 'PersonalInfo'
      klass.group_name = :update_all
      klass.sub_command_names = %i[change_name change_email]
    end
  end

  let(:personal_info_id) { SecureRandom.uuid }
  let(:first_name) { 'Ada' }
  let(:last_name) { 'Lovelace' }
  let(:email) { 'ada@example.com' }

  describe '.sub_command_classes' do
    subject { test_group_class.sub_command_classes }

    it 'resolves classes from the configuration registry in declaration order' do
      expect(subject).to eq(
        [
          Test::PersonalInfo::Commands::ChangeName::Command,
          Test::PersonalInfo::Commands::ChangeEmail::Command
        ]
      )
    end
  end

  describe '.command_contexts' do
    subject { test_group_class.command_contexts }

    it 'returns the unique context symbols of the sub-commands' do
      expect(subject).to eq(%i[test])
    end
  end

  describe '.own_context / .own_subject' do
    it 'returns the own context as a symbol' do
      expect(test_group_class.own_context).to eq(:test)
    end

    it 'returns the own subject as a symbol' do
      expect(test_group_class.own_subject).to eq(:personal_info)
    end
  end

  describe '#initialize with flat payload' do
    subject(:cmd) do
      test_group_class.new(
        personal_info_id:, first_name:, last_name:, email:
      )
    end

    it 'exposes the flat input payload via #payload (used by guard PayloadProxy)' do
      expect(cmd.payload).to eq(personal_info_id:, first_name:, last_name:, email:)
    end

    it 'exposes the normalized form under own_context.own_subject via #normalized_payload' do
      expect(cmd.normalized_payload).to eq(
        test: {
          personal_info: { personal_info_id:, first_name:, last_name:, email: }
        }
      )
    end

    it 'builds sub-command instances in declaration order with the matching attributes' do
      expect(cmd.commands.size).to eq(2)
      expect(cmd.commands[0]).to be_a(Test::PersonalInfo::Commands::ChangeName::Command)
      expect(cmd.commands[0].first_name).to eq(first_name)
      expect(cmd.commands[0].last_name).to eq(last_name)
      expect(cmd.commands[0].personal_info_id).to eq(personal_info_id)
      expect(cmd.commands[1]).to be_a(Test::PersonalInfo::Commands::ChangeEmail::Command)
      expect(cmd.commands[1].email).to eq(email)
      expect(cmd.commands[1].personal_info_id).to eq(personal_info_id)
    end

    it 'exposes the aggregate_id of the first sub-command' do
      expect(cmd.aggregate_id).to eq(personal_info_id)
    end
  end

  describe '#initialize with subject-nested payload' do
    subject(:cmd) do
      test_group_class.new(
        personal_info: { personal_info_id:, first_name:, last_name:, email: }
      )
    end

    it 'preserves the existing nesting in normalized_payload' do
      expect(cmd.normalized_payload).to eq(
        test: { personal_info: { personal_info_id:, first_name:, last_name:, email: } }
      )
    end

    it 'still instantiates sub-commands correctly' do
      expect(cmd.commands.map(&:class)).to eq([
                                                Test::PersonalInfo::Commands::ChangeName::Command,
                                                Test::PersonalInfo::Commands::ChangeEmail::Command
                                              ])
    end
  end

  describe 'reserved keys' do
    let(:transaction) { Yes::Core::TransactionDetails.new }
    let(:origin) { 'cli' }
    let(:batch_id) { SecureRandom.uuid }
    let(:metadata) { { 'meta' => 'data' } }

    subject(:cmd) do
      test_group_class.new(
        transaction:, origin:, batch_id:, metadata:,
        personal_info_id:, first_name:, last_name:, email:
      )
    end

    it 'stores reserved keys on group_attributes' do
      expect(cmd.transaction).to eq(transaction)
      expect(cmd.origin).to eq(origin)
      expect(cmd.batch_id).to eq(batch_id)
      expect(cmd.metadata).to eq(metadata)
    end

    it 'does not leak reserved keys into the flat payload' do
      aggregate_failures do
        expect(cmd.payload).not_to have_key(:transaction)
        expect(cmd.payload).not_to have_key(:origin)
        expect(cmd.payload).not_to have_key(:batch_id)
        expect(cmd.payload).not_to have_key(:metadata)
      end
    end

    it 'does not leak reserved keys into the normalized payload' do
      aggregate_failures do
        expect(cmd.normalized_payload[:test][:personal_info]).not_to have_key(:transaction)
        expect(cmd.normalized_payload[:test][:personal_info]).not_to have_key(:origin)
        expect(cmd.normalized_payload[:test][:personal_info]).not_to have_key(:batch_id)
        expect(cmd.normalized_payload[:test][:personal_info]).not_to have_key(:metadata)
      end
    end

    it 'propagates origin/batch_id/metadata/transaction to each sub-command' do
      aggregate_failures do
        cmd.commands.each do |sub|
          expect(sub.origin).to eq(origin)
          expect(sub.batch_id).to eq(batch_id)
          expect(sub.metadata).to eq(metadata)
          expect(sub.transaction).to eq(transaction)
        end
      end
    end

    it 'gives each sub-command its own command_id (group keeps its own)' do
      aggregate_failures do
        ids = cmd.commands.map(&:command_id) + [cmd.command_id]
        expect(ids).to all(be_present)
        expect(ids.uniq).to eq(ids)
      end
    end
  end

  describe '#to_h' do
    let(:batch_id) { SecureRandom.uuid }

    subject(:hashed) do
      test_group_class.new(
        batch_id:, origin: 'cli',
        personal_info_id:, first_name:, last_name:, email:
      ).to_h
    end

    it 'merges the flat payload and group attributes' do
      expect(hashed).to include(
        personal_info_id:, first_name:, last_name:, email:,
        batch_id: batch_id,
        origin: 'cli'
      )
    end

    it 'round-trips: re-instantiating from to_h produces an equivalent group' do
      original = test_group_class.new(
        batch_id:, origin: 'cli',
        personal_info_id:, first_name:, last_name:, email:
      )
      rebuilt = test_group_class.new(original.to_h)

      aggregate_failures do
        expect(rebuilt.payload).to eq(original.payload)
        expect(rebuilt.batch_id).to eq(original.batch_id)
        expect(rebuilt.origin).to eq(original.origin)
      end
    end
  end
end
