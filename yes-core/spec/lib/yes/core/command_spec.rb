# frozen_string_literal: true

RSpec.describe Yes::Core::Command do
  let(:activity_id) { SecureRandom.uuid }
  let(:transaction) do
    Yes::Core::TransactionDetails.new(
      name: 'DoSomething', correlation_id: SecureRandom.uuid
    )
  end
  let(:metadata) { { 'meta' => 'data' } }

  it 'initializes command without transaction' do
    expect(described_class.new({}).transaction).to be_nil
  end

  it 'initializes command with transaction' do
    cmd = described_class.new(transaction:)

    expect(cmd.transaction).to eq(transaction)
  end

  it 'initializes command without metadata' do
    expect(described_class.new({}).metadata).to be_nil
  end

  it 'initializes command with metadata' do
    cmd = described_class.new(metadata:)

    expect(cmd.metadata).to eq(metadata)
  end

  it 'initializes command with id' do
    cmd = described_class.new({})

    expect(cmd.command_id).not_to be_nil
  end

  it 'raises an error for invalid transaction set' do
    expect { described_class.new(transaction: Class.new) }.to(
      raise_error(Yes::Core::Command::Invalid)
    )
  end

  it 'works for nested commands' do
    cmd = Dummy::Commands::Activity::DoSomething.new(
      id: activity_id, transaction:, what: 'Clean your teeth'
    )

    aggregate_failures do
      expect(cmd.transaction).to eq(transaction)
      expect(cmd.what).to eq('Clean your teeth')
      expect(cmd.to_h).to(
        include(id: activity_id, transaction: transaction.to_h, what: 'Clean your teeth')
      )
    end
  end

  describe '#payload' do
    subject { cmd.payload }

    let(:cmd) do
      Dummy::Commands::Activity::DoSomething.new(
        id: activity_id,
        transaction:,
        origin:,
        batch_id:,
        what: 'nothing'
      )
    end
    let(:transaction) { Yes::Core::TransactionDetails.new }
    let(:origin) { 'origin' }
    let(:batch_id) { SecureRandom.uuid }

    it 'returns command payload without transaction origin and batch_id' do
      expect(subject).to eq(what: 'nothing', id: activity_id)
    end

    context 'with nullable attributes' do
      let(:cmd) do
        Dummy::Commands::Activity::DoSomethingWithNullable.new(
          id: activity_id,
          transaction:,
          origin:,
          batch_id:,
          what: 'something',
          phone:,
          age:,
          email:
        )
      end
      let(:transaction) { Yes::Core::TransactionDetails.new }
      let(:origin) { 'origin' }
      let(:batch_id) { SecureRandom.uuid }

      context 'when nullable attributes have values' do
        let(:phone) { '123456789' }
        let(:age) { 30 }
        let(:email) { 'test@example.com' }

        it 'unwraps Some monads to actual values' do
          expect(subject).to eq(
            what: 'something',
            id: activity_id,
            phone: '123456789',
            age: 30,
            email: 'test@example.com'
          )
        end

        it 'does not contain monadic wrappers' do
          aggregate_failures do
            expect(subject[:phone]).to eq('123456789')
            expect(subject[:age]).to eq(30)
            expect(subject[:email]).to eq('test@example.com')
          end
        end
      end

      context 'when nullable attributes are nil' do
        let(:phone) { nil }
        let(:age) { nil }
        let(:email) { nil }

        it 'unwraps None monads to nil' do
          expect(subject).to eq(
            what: 'something',
            id: activity_id,
            phone: nil,
            age: nil,
            email: nil
          )
        end

        it 'does not contain None monads' do
          aggregate_failures do
            expect(subject[:phone]).to be_nil
            expect(subject[:age]).to be_nil
            expect(subject[:email]).to be_nil
          end
        end
      end

      context 'when nullable attributes are mixed (some nil, some values)' do
        let(:phone) { '123456789' }
        let(:age) { nil }
        let(:email) { 'test@example.com' }

        it 'correctly unwraps both Some and None monads' do
          expect(subject).to eq(
            what: 'something',
            id: activity_id,
            phone: '123456789',
            age: nil,
            email: 'test@example.com'
          )
        end
      end

      context 'when non-nullable attributes are present' do
        let(:phone) { '123456789' }
        let(:age) { 30 }
        let(:email) { 'test@example.com' }

        it 'leaves non-nullable attributes unchanged' do
          expect(subject[:what]).to eq('something')
          expect(subject[:id]).to eq(activity_id)
        end
      end
    end
  end
end
