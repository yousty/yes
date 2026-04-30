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
      # would raise NoChangeTransition. Asserting InvalidTransition (a sibling, not a parent)
      # proves the pre-check shadowed the registered guard.
      result = nil
      begin
        guard_evaluator.call
      rescue described_class::TransitionError => e
        result = e
      end
      expect(result).to be_a(described_class::InvalidTransition)
      expect(result).not_to be_a(described_class::NoChangeTransition)
    end
  end
end
