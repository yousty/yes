# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Draftable do
  let(:aggregate_class) do
    Class.new(Yes::Core::Aggregate) do
      def self.name
        'TestContext::TestAggregate::Aggregate'
      end

      def self.context
        'TestContext'
      end

      def self.aggregate
        'TestAggregate'
      end

      def self.read_model_name
        'test_aggregate'
      end

      def self.read_model_class
        OpenStruct
      end
    end
  end

  let(:draftable_aggregate_class) do
    Class.new(aggregate_class) do
      draftable
      changes_read_model
    end
  end

  let(:custom_draftable_aggregate_class) do
    Class.new(aggregate_class) do
      draftable context: 'CustomContext', aggregate: 'CustomDraft'
      changes_read_model :custom_change
      draft_foreign_key :custom_foreign_key
    end
  end

  describe '.draftable' do
    context 'with default parameters' do
      subject { draftable_aggregate_class }

      it 'sets is_draftable to true' do
        expect(subject.draftable?).to be true
      end

      it 'uses the same context as the aggregate' do
        expect(subject.draft_context).to eq('TestContext')
      end

      it 'appends Draft to the aggregate name' do
        expect(subject.draft_aggregate).to eq('TestAggregateDraft')
      end
    end

    context 'with custom parameters' do
      subject { custom_draftable_aggregate_class }

      it 'sets is_draftable to true' do
        expect(subject.draftable?).to be true
      end

      it 'uses the custom context' do
        expect(subject.draft_context).to eq('CustomContext')
      end

      it 'uses the custom aggregate name' do
        expect(subject.draft_aggregate).to eq('CustomDraft')
      end
    end

    context 'when not draftable' do
      subject { aggregate_class }

      it 'returns false for draftable?' do
        expect(subject.draftable?).to be false
      end

      it 'returns nil for draft_context' do
        expect(subject.draft_context).to be_nil
      end

      it 'returns nil for draft_aggregate' do
        expect(subject.draft_aggregate).to be_nil
      end
    end
  end

  describe '.changes_read_model' do
    context 'with default parameter' do
      subject { draftable_aggregate_class }

      it 'appends _change to the read model name' do
        expect(subject.draft_read_model_name).to eq('test_aggregate_change')
      end
    end

    context 'with custom parameter' do
      subject { custom_draftable_aggregate_class }

      it 'uses the custom draft read model name' do
        expect(subject.draft_read_model_name).to eq('custom_change')
      end
    end
  end

  describe '.change_foreign_key' do
    context 'with default' do
      subject { draftable_aggregate_class }

      it 'generates the default foreign key' do
        expect(subject.change_foreign_key).to eq('test_aggregate_change_id')
      end
    end

    context 'with custom foreign key' do
      subject { custom_draftable_aggregate_class }

      it 'uses the custom foreign key' do
        expect(subject.change_foreign_key).to eq('custom_foreign_key')
      end
    end
  end

  describe '#initialize' do
    context 'when aggregate is draftable' do
      it 'allows initialization with draft: true' do
        expect { draftable_aggregate_class.new(draft: true) }.not_to raise_error
      end

      it 'allows initialization with draft: false' do
        expect { draftable_aggregate_class.new(draft: false) }.not_to raise_error
      end

      it 'allows initialization without draft parameter' do
        expect { draftable_aggregate_class.new }.not_to raise_error
      end

      it 'sets draft instance variable correctly' do
        draft_instance = draftable_aggregate_class.new(draft: true)
        expect(draft_instance.instance_variable_get(:@draft)).to be true

        normal_instance = draftable_aggregate_class.new(draft: false)
        expect(normal_instance.instance_variable_get(:@draft)).to be false
      end
    end

    context 'when aggregate is not draftable' do
      it 'raises ArgumentError when initialized with draft: true' do
        expect { aggregate_class.new(draft: true) }.to raise_error(
          ArgumentError,
          /is not draftable. Add 'draftable' to the class definition/
        )
      end

      it 'allows initialization with draft: false' do
        expect { aggregate_class.new(draft: false) }.not_to raise_error
      end

      it 'allows initialization without draft parameter' do
        expect { aggregate_class.new }.not_to raise_error
      end
    end
  end

  describe '#draft?' do
    context 'when aggregate is draftable' do
      context 'when initialized with draft: true' do
        subject { draftable_aggregate_class.new(draft: true) }

        it 'returns true' do
          expect(subject.draft?).to be true
        end
      end

      context 'when initialized with draft: false' do
        subject { draftable_aggregate_class.new(draft: false) }

        it 'returns false' do
          expect(subject.draft?).to be false
        end
      end

      context 'when initialized without draft parameter' do
        subject { draftable_aggregate_class.new }

        it 'returns false' do
          expect(subject.draft?).to be false
        end
      end
    end

    context 'when aggregate is not draftable' do
      context 'when initialized without draft parameter' do
        subject { aggregate_class.new }

        it 'returns false' do
          expect(subject.draft?).to be false
        end
      end

      context 'when initialized with draft: false' do
        subject { aggregate_class.new(draft: false) }

        it 'returns false' do
          expect(subject.draft?).to be false
        end
      end
    end
  end

  describe '#read_model' do
    let(:draft_read_model_class) { double('DraftReadModelClass') }
    let(:normal_read_model_class) { double('NormalReadModelClass') }
    let(:draft_read_model_instance) { double('DraftReadModel') }
    let(:normal_read_model_instance) { double('NormalReadModel') }

    before do
      allow(draftable_aggregate_class).to receive(:read_model_class).and_return(normal_read_model_class)
      allow(normal_read_model_class).to receive(:find_or_create_by).and_return(normal_read_model_instance)
      allow(draft_read_model_class).to receive(:find_or_create_by).and_return(draft_read_model_instance)
    end

    context 'when initialized as draft' do
      subject { draftable_aggregate_class.new('test-id', draft: true) }

      it 'returns the draft read model' do
        allow(subject).to receive(:draft_read_model_class).and_return(draft_read_model_class)
        expect(subject.read_model).to eq(draft_read_model_instance)
      end
    end

    context 'when not initialized as draft' do
      subject { draftable_aggregate_class.new('test-id', draft: false) }

      it 'returns the normal read model' do
        expect(subject.read_model).to eq(normal_read_model_instance)
      end
    end
  end

  describe '#update_read_model' do
    let(:draft_instance) { draftable_aggregate_class.new('test-id', draft: true) }
    let(:normal_instance) { draftable_aggregate_class.new('test-id', draft: false) }
    let(:read_model) { double('ReadModel', update!: true) }

    before do
      allow(draft_instance).to receive(:read_model).and_return(read_model)
      allow(normal_instance).to receive(:read_model).and_return(read_model)
      allow(I18n).to receive(:with_locale).and_yield
    end

    context 'when initialized as draft' do
      it 'updates the read model' do
        expect(read_model).to receive(:update!).with(hash_including(name: 'Test'))
        # Mock update_connected_draft_aggregate to avoid TestContext constant error
        allow(draft_instance).to receive(:update_connected_draft_aggregate)
        draft_instance.update_read_model(name: 'Test')
      end

      it 'calls update_connected_draft_aggregate' do
        allow(read_model).to receive(:update!)
        expect(draft_instance).to receive(:update_connected_draft_aggregate)
        draft_instance.update_read_model(name: 'Test')
      end
    end

    context 'when not initialized as draft' do
      it 'updates the read model' do
        expect(read_model).to receive(:update!).with(hash_including(name: 'Test'))
        normal_instance.update_read_model(name: 'Test')
      end

      it 'does not call update_connected_draft_aggregate' do
        allow(read_model).to receive(:update!)
        expect(normal_instance).not_to receive(:update_connected_draft_aggregate)
        normal_instance.update_read_model(name: 'Test')
      end
    end
  end

  describe '#update_connected_draft_aggregate' do
    let(:draft_instance) { draftable_aggregate_class.new('test-id', draft: true) }
    let(:draft_aggregate_class_mock) { double('DraftAggregateClass') }
    let(:draft_read_model_class) { double('DraftReadModelClass') }
    let(:draft_read_model) { double('DraftReadModel') }
    let(:read_model) { double('ReadModel', update!: true) }
    before do
      allow(draft_instance).to receive(:read_model).and_return(read_model)
      allow(read_model).to receive(:test_aggregate).and_return('base-id')
      allow(I18n).to receive(:with_locale).and_yield
    end

    context 'when draft aggregate exists' do
      before do
        stub_const('TestContext::TestAggregateDraft', draft_aggregate_class_mock)
        allow(draft_aggregate_class_mock).to receive(:read_model_class).and_return(draft_read_model_class)
        allow(draft_read_model_class).to receive(:states).and_return({ draft: 'draft' })
        allow(draft_read_model_class).to receive(:find_by).
          with('test_aggregate_change_id' => 'base-id').
          and_return(draft_read_model)
      end

      it 'updates the draft aggregate read model state' do
        expect(draft_read_model).to receive(:update).with(state: 'draft')
        draft_instance.update_read_model(name: 'Test')
      end
    end

    context 'when draft aggregate does not exist' do
      before do
        stub_const('TestContext::TestAggregateDraft', draft_aggregate_class_mock)
        allow(draft_aggregate_class_mock).to receive(:read_model_class).and_return(draft_read_model_class)
        allow(draft_read_model_class).to receive(:states).and_return({ draft: 'draft' })
        allow(draft_read_model_class).to receive(:find_by).
          with('test_aggregate_change_id' => 'base-id').
          and_return(nil)
      end

      it 'does not raise an error' do
        expect { draft_instance.update_read_model(name: 'Test') }.not_to raise_error
      end
    end

    context 'when skip_draft_aggregate_update? returns true' do
      before do
        allow(draft_instance).to receive(:skip_draft_aggregate_update?).and_return(true)
      end

      it 'does not update the draft aggregate' do
        # The update_connected_draft_aggregate method will be called but will return early
        # because skip_draft_aggregate_update? returns true
        expect { draft_instance.update_read_model(name: 'Test') }.not_to raise_error
      end
    end
  end

  describe '#build_command_utilities' do
    context 'when initialized as draft and is draftable' do
      let(:draft_instance) { draftable_aggregate_class.new('test-id', draft: true) }

      it 'uses draft context and aggregate' do
        command_utils = draft_instance.send(:build_command_utilities)
        expect(command_utils.instance_variable_get(:@context)).to eq('TestContext')
        expect(command_utils.instance_variable_get(:@aggregate)).to eq('TestAggregateDraft')
      end
    end

    context 'when initialized as draft with custom settings' do
      let(:draft_instance) { custom_draftable_aggregate_class.new('test-id', draft: true) }

      it 'uses custom draft context and aggregate' do
        command_utils = draft_instance.send(:build_command_utilities)
        expect(command_utils.instance_variable_get(:@context)).to eq('CustomContext')
        expect(command_utils.instance_variable_get(:@aggregate)).to eq('CustomDraft')
      end
    end

    context 'when not initialized as draft' do
      let(:normal_instance) { draftable_aggregate_class.new('test-id', draft: false) }

      it 'uses normal context and aggregate' do
        command_utils = normal_instance.send(:build_command_utilities)
        expect(command_utils.instance_variable_get(:@context)).to eq('TestContext')
        expect(command_utils.instance_variable_get(:@aggregate)).to eq('TestAggregate')
      end
    end
  end

  describe 'edge cases' do
    context 'when using partial draftable configuration' do
      let(:partial_draftable_class) do
        Class.new(aggregate_class) do
          draftable context: 'PartialContext'
          # No changes_read_model call
        end
      end

      it 'allows draft initialization' do
        expect { partial_draftable_class.new(draft: true) }.not_to raise_error
      end

      it 'uses custom context and default aggregate name' do
        expect(partial_draftable_class.draft_context).to eq('PartialContext')
        expect(partial_draftable_class.draft_aggregate).to eq('TestAggregateDraft')
      end

      it 'has nil draft_read_model_name when not set' do
        expect(partial_draftable_class.draft_read_model_name).to be_nil
      end
    end

    context 'when overriding skip_draft_aggregate_update?' do
      let(:skip_override_class) do
        Class.new(aggregate_class) do
          draftable
          changes_read_model

          private

          def skip_draft_aggregate_update?
            true
          end
        end
      end

      it 'respects the override' do
        instance = skip_override_class.new(draft: true)
        read_model = double('ReadModel', update!: true)
        allow(instance).to receive(:read_model).and_return(read_model)
        allow(I18n).to receive(:with_locale).and_yield

        # Should not attempt to constantize or do any draft aggregate update
        expect { instance.update_read_model(name: 'Test') }.not_to raise_error
      end
    end
  end

  describe 'integration with command utilities' do
    context 'when initializing with draft mode' do
      let(:draft_instance) { custom_draftable_aggregate_class.new('test-id', draft: true) }

      it 'command utilities use draft context and aggregate' do
        utils = draft_instance.instance_variable_get(:@command_utilities)
        expect(utils.instance_variable_get(:@context)).to eq('CustomContext')
        expect(utils.instance_variable_get(:@aggregate)).to eq('CustomDraft')
        expect(utils.instance_variable_get(:@aggregate_id)).to eq('test-id')
      end
    end

    context 'when initializing without draft mode' do
      let(:normal_instance) { custom_draftable_aggregate_class.new('test-id', draft: false) }

      it 'command utilities use normal context and aggregate' do
        utils = normal_instance.instance_variable_get(:@command_utilities)
        expect(utils.instance_variable_get(:@context)).to eq('TestContext')
        expect(utils.instance_variable_get(:@aggregate)).to eq('TestAggregate')
        expect(utils.instance_variable_get(:@aggregate_id)).to eq('test-id')
      end
    end
  end
end
