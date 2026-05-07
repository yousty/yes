# frozen_string_literal: true

require 'yes/core/test_support/aggregate/command_test_dsl'

RSpec.describe Yes::Core::TestSupport::Aggregate::CommandTestDsl do
  describe '.expected_event_prefix' do
    subject { described_class.expected_event_prefix(aggregate_class, draft:) }

    let(:non_draftable_aggregate_class) do
      Class.new do
        def self.aggregate
          'User'
        end
      end
    end

    let(:legacy_draftable_aggregate_class) do
      Class.new do
        def self.aggregate
          'User'
        end

        def self._changes_read_model_explicit
          false
        end
      end
    end

    let(:explicit_changes_read_model_aggregate_class) do
      Class.new do
        def self.aggregate
          'Recruiter'
        end

        def self._changes_read_model_explicit
          true
        end

        def self.changes_read_model_name
          'user_edit_template'
        end
      end
    end

    context 'when draft is false' do
      let(:draft) { false }
      let(:aggregate_class) { explicit_changes_read_model_aggregate_class }

      it 'returns the bare aggregate name' do
        is_expected.to eq('Recruiter')
      end
    end

    context 'when draft is true and the aggregate is not draftable' do
      let(:draft) { true }
      let(:aggregate_class) { non_draftable_aggregate_class }

      it 'falls back to the legacy <Aggregate>Draft suffix' do
        is_expected.to eq('UserDraft')
      end
    end

    context 'when draft is true and changes_read_model was not set explicitly' do
      let(:draft) { true }
      let(:aggregate_class) { legacy_draftable_aggregate_class }

      it 'falls back to the legacy <Aggregate>Draft suffix' do
        is_expected.to eq('UserDraft')
      end
    end

    context 'when draft is true and changes_read_model was set explicitly' do
      let(:draft) { true }
      let(:aggregate_class) { explicit_changes_read_model_aggregate_class }

      it 'returns the camelized changes_read_model_name (DSL config wins over default)' do
        is_expected.to eq('UserEditTemplate')
      end
    end
  end
end
