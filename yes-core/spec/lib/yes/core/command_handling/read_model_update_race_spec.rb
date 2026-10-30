# frozen_string_literal: true

# Two writers apply the same event to one read model row: a slow one that has already passed the
# revision guard and a fast one that applies that event and the next one in the meantime.
# Needs committed data and one DB connection per thread, hence no transactional tests.
RSpec.describe Yes::Core::CommandHandling::ReadModelUpdater, 'concurrent writers' do
  self.use_transactional_tests = false

  # Subjects and lets are memoized under a lock that is held while the block runs, so the thread must not
  # call them: everything it needs is passed in.
  subject(:run_race) do
    paused = slow_writer_paused
    release = slow_writer_release
    slow_writer = Thread.new { apply_as_slow_writer(paused, release) }
    wait_for(paused)
    apply_as_fast_writer
    release << :go
    expect(slow_writer.join(THREAD_TIMEOUT)).not_to be_nil
  end

  THREAD_TIMEOUT = 10

  let(:user_id) { SecureRandom.uuid }
  let(:contested_revision) { 1 }
  let(:slow_writer_paused) { Queue.new }
  let(:slow_writer_release) { Queue.new }

  before { TestUser.create!(id: user_id, revision: contested_revision - 1) }

  after { TestUser.where(id: user_id).delete_all }

  def wait_for(queue)
    Timeout.timeout(THREAD_TIMEOUT) { queue.pop }
  end

  def event_at(revision)
    Yes::Core::Event.new(id: SecureRandom.uuid, type: 'Test::User::DocumentsApproved', data: {}).tap do |event|
      event.stream_revision = revision
    end
  end

  def apply(aggregate, revision, payload)
    described_class.new(aggregate).call(event_at(revision), payload, :approve_documents)
  end

  # Pauses right after the revision guard's first check, i.e. after it decided to write.
  def pause_after_first_reload(read_model, paused, release)
    reloads = 0
    read_model.define_singleton_method(:reload) do |*args|
      super(*args).tap do
        reloads += 1
        next unless reloads == 1

        paused << :paused
        Timeout.timeout(THREAD_TIMEOUT) { release.pop }
      end
    end
  end

  def apply_as_slow_writer(paused, release)
    ActiveRecord::Base.connection_pool.with_connection do
      aggregate = Test::User::Aggregate.new(user_id)
      pause_after_first_reload(aggregate.read_model, paused, release)
      apply(aggregate, contested_revision, { document_ids: 'from slow writer' })
    end
  end

  def apply_as_fast_writer
    aggregate = Test::User::Aggregate.new(user_id)
    apply(aggregate, contested_revision, { document_ids: 'from fast writer' })
    apply(aggregate, contested_revision + 1, { another: 'from fast writer' })
  end

  it 'keeps the state of the faster writer and skips the already applied event' do
    run_race

    aggregate_failures do
      expect(TestUser.find(user_id).revision).to eq(contested_revision + 1)
      expect(TestUser.find(user_id).document_ids).to eq('from fast writer')
      expect(TestUser.find(user_id).another).to eq('from fast writer')
    end
  end
end
