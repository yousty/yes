# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::ReadModelRevisionGuard, 'with a retried transaction' do
  subject(:call_guard) do
    described_class.call(read_model, expected_revision) do
      self.attempts += 1
      read_model.name = "attempt #{attempts}"
      read_model.revision = expected_revision
      read_model.save!
      raise ActiveRecord::SerializationFailure, 'could not serialize access' if attempts == 1

      :written
    end
  end

  let(:read_model) { TestUser.create!(id: SecureRandom.uuid, revision: 0) }
  let(:expected_revision) { 1 }

  # Counts the runs of the guarded block.
  attr_accessor :attempts

  # Mimics what a transaction retry extension does: runs the whole transaction block once more after a
  # serialization failure. The record is dirty again on that second run because Rails restores its
  # pre-transaction state when the transaction rolls back, so the changes of the first attempt are unsaved again.
  # Stubbed per example, so it cannot leak into other specs.
  before do
    self.attempts = 0
    retried = false
    allow(TestUser.connection).to receive(:transaction).and_wrap_original do |original, **options, &block|
      original.call(**options, &block)
    rescue ActiveRecord::SerializationFailure
      raise if retried

      retried = true
      retry
    end
  end

  it 'locks the row again and runs the block a second time' do
    aggregate_failures do
      expect(call_guard).to eq(:written)
      expect(attempts).to eq(2)
      expect(read_model.reload.revision).to eq(expected_revision)
    end
  end
end
