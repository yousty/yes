# frozen_string_literal: true

RSpec.describe Yes::Core::Commands::Group do
  let(:metadata) { nil }
  let(:transaction) { nil }
  let(:origin) { 'origin' }
  let(:batch_id) { SecureRandom.uuid }
  let(:company_id) { SecureRandom.uuid }
  let(:company_name) { 'Company' }
  let(:user_id) { SecureRandom.uuid }
  let(:first_name) { 'User' }
  let(:last_name) { 'Name' }
  let(:description) { 'Description' }

  let(:cmd) do
    Dummy::Company::Commands::DoSomethingCompounded::Command.new(
      transaction:,
      origin:,
      batch_id:,
      company: { company_id:, name: company_name, description: }, user: { user_id:, first_name:, last_name: }, metadata:
    )
  end

  context 'without transaction' do
    it 'initializes command group without transaction' do
      expect(cmd.transaction).to be_nil
    end
  end

  context 'with transaction' do
    let(:transaction) { Yes::Core::TransactionDetails.new }

    it 'initializes command group with transaction' do
      expect(cmd.transaction).to eq(transaction)
    end
  end

  context 'without metadata' do
    it 'initializes command group without metadata' do
      expect(cmd.metadata).to be_nil
    end
  end

  context 'with metadata' do
    let(:metadata) { { 'meta' => 'data' } }

    it 'initializes command group with transaction' do
      expect(cmd.metadata).to eq(metadata)
    end
  end

  it 'initializes command group with id' do
    expect(cmd.command_id).not_to be_nil
  end


  context 'invalid transaction' do
    let(:transaction) { Class.new }

    it 'raises an error for invalid transaction set' do
      expect { cmd }.to(
        raise_error(Yes::Core::Commands::Group::Attributes::Invalid)
      )
    end
  end

  describe '#new' do
    subject { cmd }

    it { is_expected.to be_a(Yes::Core::Commands::Group) }
  end

  describe '#payload' do
    subject { cmd.payload }

    it 'returns command payload grouped by context and subject, without command base attributes' do
      expect(subject).to(
        eq(
          dummy: {
            company: { company_id:, name: company_name, description:},
            user: { user_id:, first_name:, last_name: }
          }
        )
      )
    end
  end
end
