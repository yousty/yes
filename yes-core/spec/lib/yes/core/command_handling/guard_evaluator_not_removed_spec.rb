# frozen_string_literal: true

# Coverage for the auto-injected `:not_removed` pre-check that runs at the top of
# Yes::Core::CommandHandling::GuardEvaluator#call. The check fires for every command on a
# `removable` aggregate (other than commands that opted out via `skip_default_guards`) once
# `removed_at` is set, ahead of any registered guard (including the auto-injected `:no_change`).
RSpec.describe Yes::Core::CommandHandling::GuardEvaluator do
  subject(:guard_evaluator) { guard_evaluator_class.new(payload:, metadata:, aggregate:, command_name:) }

  let(:guard_evaluator_class) do
    Class.new(described_class) do
      def self.name
        'Test::User::TestCommand::GuardEvaluator'
      end
    end
  end

  let(:payload)      { {} }
  let(:metadata)     { {} }
  let(:command_name) { :test_command }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:aggregate)    { aggregate_class.new }
  let(:command_data) { instance_double(Yes::Core::Aggregate::Dsl::CommandData, skip_default_guards:) }
  let(:skip_default_guards) { [] }

  before do
    allow(aggregate_class).to receive(:commands).and_return(command_name => command_data)
    allow(aggregate).to receive(:removed_at).and_return(removed_at)
  end

  let(:removed_at) { nil }

  after do
    aggregate_class.instance_variable_set(:@removable_config, nil)
  end

  context 'when the aggregate is not removable' do
    before { aggregate_class.instance_variable_set(:@removable_config, nil) }

    let(:removed_at) { Time.current }

    it 'is a no-op even when an attribute named removed_at is set' do
      expect { guard_evaluator.send(:check_not_removed!) }.not_to raise_error
    end
  end

  context 'when removable but not_removed_guards: false' do
    before do
      aggregate_class.instance_variable_set(
        :@removable_config, { attr_name: :removed_at, not_removed_guards: false }
      )
    end

    let(:removed_at) { Time.current }

    it 'is a no-op' do
      expect { guard_evaluator.send(:check_not_removed!) }.not_to raise_error
    end
  end

  context 'when removable + not_removed_guards: true' do
    before do
      aggregate_class.instance_variable_set(
        :@removable_config, { attr_name: :removed_at, not_removed_guards: true }
      )
    end

    context 'and removed_at is blank' do
      let(:removed_at) { nil }

      it 'is a no-op' do
        expect { guard_evaluator.send(:check_not_removed!) }.not_to raise_error
      end
    end

    context 'and removed_at is set' do
      let(:removed_at) { Time.current }

      it 'raises InvalidTransition' do
        expect { guard_evaluator.send(:check_not_removed!) }.
          to raise_error(described_class::InvalidTransition)
      end

      it 'looks up the message under the not_removed guard key' do
        expect(Yes::Core::ErrorMessages).to receive(:guard_error).
          with('Test', 'User', command_name.to_s, :not_removed).
          and_return('blocked')

        expect { guard_evaluator.send(:check_not_removed!) }.
          to raise_error(described_class::InvalidTransition, 'blocked')
      end

      context 'and the command opts out via skip_default_guards' do
        let(:skip_default_guards) { %i[not_removed] }

        it 'is a no-op' do
          expect { guard_evaluator.send(:check_not_removed!) }.not_to raise_error
        end
      end
    end

    context 'with a custom attr_name' do
      before do
        aggregate_class.instance_variable_set(
          :@removable_config, { attr_name: :archived_at, not_removed_guards: true }
        )
        allow(aggregate).to receive(:archived_at).and_return(archived_at)
      end

      context 'when the attribute is set' do
        let(:archived_at) { Time.current }

        it 'raises InvalidTransition' do
          expect { guard_evaluator.send(:check_not_removed!) }.
            to raise_error(described_class::InvalidTransition)
        end
      end

      context 'when the attribute is blank' do
        let(:archived_at) { nil }

        it 'is a no-op' do
          expect { guard_evaluator.send(:check_not_removed!) }.not_to raise_error
        end
      end
    end
  end

  describe '#call ordering' do
    before do
      aggregate_class.instance_variable_set(
        :@removable_config, { attr_name: :removed_at, not_removed_guards: true }
      )
      # A registered guard that would otherwise raise NoChangeTransition.
      guard_evaluator_class.guard(:no_change) { false }
    end

    let(:removed_at) { Time.current }

    it 'fires the not_removed pre-check before iterating registered guards' do
      # If the pre-check did not run first, the registered `:no_change` (which returns false)
      # would raise NoChangeTransition. Asserting InvalidTransition (a sibling, not a parent
      # — see `class TransitionError; class InvalidTransition; class NoChangeTransition <
      # TransitionError`) proves the pre-check shadowed the registered guard.
      expect { guard_evaluator.call }.to raise_error(described_class::InvalidTransition) do |e|
        expect(e).not_to be_a(described_class::NoChangeTransition)
      end
    end
  end

  describe ':remove command opt-out' do
    let(:command_name) { :remove }
    let(:skip_default_guards) { %i[not_removed] }
    let(:removed_at) { Time.current }

    before do
      aggregate_class.instance_variable_set(
        :@removable_config, { attr_name: :removed_at, not_removed_guards: true }
      )
      # `removable` registers `:remove` with this opt-out flag, mirrored here. The pre-check
      # reads `command_data.skip_default_guards` and bails out, so the registered `:no_change`
      # is the gate that fires on a double-remove (NoChangeTransition, not InvalidTransition).
      guard_evaluator_class.guard(:no_change) { false }
    end

    it 'allows the registered :no_change guard to fire instead of the pre-check' do
      expect { guard_evaluator.call }.to raise_error(described_class::NoChangeTransition)
    end
  end
end

# Integration coverage that exercises the full DSL path (`Class.new(Yes::Core::Aggregate)` +
# `removable` + `command` + `parent`) rather than stubbing out the guard evaluator. These
# tests rely on the `Aggregate.removable_config` reader and `CommandData#skip_default_guards`
# being threaded correctly through the macros.
RSpec.describe 'removable :not_removed auto-block (integration)' do
  # Build a fresh aggregate class with the requested wiring. `removable` fires either before
  # or after the other commands depending on `removable_position` so we can exercise both
  # declaration orders.
  def build_aggregate_class(name:, removable_kwargs: {}, removable_position: :first, parent_kwargs: {})
    klass_name = name
    rk = removable_kwargs
    rp = removable_position
    pk = parent_kwargs

    Class.new(Yes::Core::Aggregate) do
      define_singleton_method(:name) { klass_name }
      primary_context klass_name.split('::').first

      removable(**rk) if rp == :first

      attribute :title, :string
      command :assign_owner, **pk do
        payload owner_id: :uuid
        guard(:no_change) { @owner_id_set != true }
        update_state custom: true do
          # No-op: we just need a custom updater so the guard evaluator skips the auto :no_change
          # logic that reads payload values from non-existent read-model columns.
          @owner_id_set = true
        end
      end

      command :change_title do
        payload title: :string
        guard(:no_change) { title != payload.title }
        update_state { title { payload.title } }
      end

      removable(**rk) if rp == :last
    end
  end

  let(:aggregate_class) do
    build_aggregate_class(name: 'IntCtx::IntAgg::Aggregate')
  end

  let(:aggregate) { aggregate_class.new }

  before do
    # Stub out the read-model writes so we don't need an AR table backing the test class.
    allow_any_instance_of(aggregate_class).to receive(:update_read_model)
    # ActiveRecord-style transaction wrapper invoked by the executor when persisting
    # pending-update state; pass through without hitting the DB.
    allow(ActiveRecord::Base).to receive(:transaction).and_yield
    # `as_null_object` lets the read_model double absorb any attribute reader the auto-generated
    # accessors call (`read_model.public_send(name)`) without per-attribute stubbing. The double
    # returns itself for unknown methods, so `title` reads as the double — sufficient for
    # `:no_change` checks of the form `title != payload.title` (always unequal).
    fake_read_model = double('ReadModel', update_column: true, reload: nil, revision: 0, id: aggregate.id).as_null_object
    allow_any_instance_of(aggregate_class).to receive(:read_model).and_return(fake_read_model)
    # Drive the aggregate to a "removed" state directly via the attribute getter, sidestepping
    # the read-model-backed accessor used by the auto-generated attribute reader.
    allow(aggregate).to receive(:removed_at).and_return(removed_at)
  end

  let(:removed_at) { nil }

  context 'when removed_at is set (default not_removed_guards: true)' do
    let(:removed_at) { Time.current }

    it 'blocks a manual command' do
      response = aggregate.assign_owner(owner_id: SecureRandom.uuid)
      expect(response.success?).to be(false)
      expect(response.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)
    end

    it 'blocks a change shortcut command' do
      response = aggregate.change_title(title: 'New')
      expect(response.success?).to be(false)
      expect(response.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)
    end

    it 'still allows :remove (gated only by :no_change, not the pre-check)' do
      # Calling :remove on an already-removed aggregate must surface NoChangeTransition,
      # not InvalidTransition — the pre-check is opted out for :remove via skip_default_guards.
      response = aggregate.remove
      expect(response.success?).to be(false)
      expect(response.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::NoChangeTransition)
    end
  end

  context 'with not_removed_guards: false' do
    let(:aggregate_class) do
      build_aggregate_class(
        name: 'IntCtx::IntAggDisabled::Aggregate',
        removable_kwargs: { not_removed_guards: false }
      )
    end
    let(:removed_at) { Time.current }

    # `can_<cmd>?` runs the GuardEvaluator (including the pre-check) without going through the
    # full command pipeline. Returning true here proves the pre-check did not fire.
    it 'does not auto-block commands after remove' do
      expect(aggregate.can_change_title?(title: 'New')).to be(true)
    end
  end

  context 'with command-level skip_default_guards: %i[not_removed]' do
    let(:aggregate_class) do
      build_aggregate_class(
        name: 'IntCtx::IntAggCmdOptout::Aggregate',
        parent_kwargs: { skip_default_guards: %i[not_removed] }
      )
    end
    let(:removed_at) { Time.current }

    it 'exempts the opted-out command from the auto-block' do
      expect(aggregate.can_assign_owner?(owner_id: SecureRandom.uuid)).to be(true)
    end

    it 'still blocks sibling commands that did not opt out' do
      response = aggregate.change_title(title: 'New')
      expect(response.success?).to be(false)
      expect(response.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)
    end
  end

  context 'when removable is declared AFTER other commands' do
    let(:aggregate_class) do
      build_aggregate_class(name: 'IntCtx::IntAggLate::Aggregate', removable_position: :last)
    end
    let(:removed_at) { Time.current }

    it 'still auto-blocks (the pre-check reads class config at runtime)' do
      response = aggregate.change_title(title: 'New')
      expect(response.success?).to be(false)
      expect(response.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)
    end
  end
end
