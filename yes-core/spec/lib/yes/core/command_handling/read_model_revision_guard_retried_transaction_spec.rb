# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::ReadModelRevisionGuard, 'with a retried transaction' do
  subject(:call_guard) do
    described_class.call(read_model, expected_revision) do
      attempts << attempt_number
      read_model.name = "attempt #{attempts.size}"
      read_model.revision = expected_revision
      read_model.save!
      raise ActiveRecord::SerializationFailure, 'could not serialize access' if attempts.size == 1

      :written
    end
  end

  # Mimics what a transaction retry extension does: runs the whole transaction block again after a
  # serialization failure, without discarding the unsaved changes of the records the block touched.
  let(:transaction_retrying_once) do
    Module.new do
      def transaction(**, &)
        retried = false
        super
      rescue ActiveRecord::SerializationFailure
        raise if retried

        retried = true
        retry
      end
    end
  end

  let(:read_model) { TestUser.create!(id: SecureRandom.uuid, revision: 0) }
  let(:expected_revision) { 1 }
  let(:attempts) { [] }
  let(:attempt_number) { attempts.size + 1 }

  before { TestUser.connection.extend(transaction_retrying_once) }

  it 'locks the row again and runs the block a second time' do
    aggregate_failures do
      expect(call_guard).to eq(:written)
      expect(attempts.size).to eq(2)
      expect(read_model.reload.revision).to eq(expected_revision)
    end
  end
end
