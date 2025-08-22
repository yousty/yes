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
    end
  end

  let(:custom_draftable_aggregate_class) do
    Class.new(aggregate_class) do
      draftable draft_aggregate: { context: 'CustomContext', aggregate: 'CustomDraft' }, changes_read_model: :custom_change
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

    context 'with only aggregate specified in draft_aggregate' do
      let(:aggregate_only_class) do
        Class.new(aggregate_class) do
          draftable draft_aggregate: { aggregate: 'OnlyAggregateDraft' }
        end
      end

      subject { aggregate_only_class }

      it 'uses custom aggregate name' do
        expect(subject.draft_aggregate).to eq('OnlyAggregateDraft')
      end

      it 'uses default context' do
        expect(subject.draft_context).to eq('TestContext')
      end
    end
  end

  describe 'changes_read_model configuration' do
    context 'when not specified (default)' do
      subject { draftable_aggregate_class }

      it 'appends _change to the read model name' do
        expect(subject.changes_read_model_name).to eq('test_aggregate_change')
      end
    end

    context 'when specified as parameter' do
      subject { custom_draftable_aggregate_class }

      it 'uses the custom changes read model name' do
        expect(subject.changes_read_model_name).to eq('custom_change')
      end
    end
  end

  describe 'changes_read_model_public configuration' do
    context 'when not specified (default)' do
      subject { draftable_aggregate_class }

      it 'defaults to true (public)' do
        expect(subject.changes_read_model_public?).to be true
      end
    end

    context 'when explicitly set to true' do
      let(:public_changes_class) do
        Class.new(aggregate_class) do
          draftable changes_read_model_public: true
        end
      end

      subject { public_changes_class }

      it 'returns true for changes_read_model_public?' do
        expect(subject.changes_read_model_public?).to be true
      end
    end

    context 'when explicitly set to false' do
      let(:private_changes_class) do
        Class.new(aggregate_class) do
          draftable changes_read_model_public: false
        end
      end

      subject { private_changes_class }

      it 'returns false for changes_read_model_public?' do
        expect(subject.changes_read_model_public?).to be false
      end
    end

    context 'when combined with other options' do
      let(:combined_options_class) do
        Class.new(aggregate_class) do
          draftable draft_aggregate: { context: 'CustomContext' }, 
                   changes_read_model: :custom_model,
                   changes_read_model_public: false
        end
      end

      subject { combined_options_class }

      it 'correctly sets all options' do
        aggregate_failures do
          expect(subject.draft_context).to eq('CustomContext')
          expect(subject.changes_read_model_name).to eq('custom_model')
          expect(subject.changes_read_model_public?).to be false
        end
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
    let(:changes_read_model_class) { double('ChangesReadModelClass') }
    let(:normal_read_model_class) { double('NormalReadModelClass') }
    let(:changes_read_model_instance) { double('ChangesReadModel') }
    let(:normal_read_model_instance) { double('NormalReadModel') }
    let(:aggregate_id) { 'test-id' }

    before do
      allow(draftable_aggregate_class).to receive(:read_model_class).and_return(normal_read_model_class)
      allow(normal_read_model_class).to receive(:find_or_create_by).with(id: aggregate_id).and_return(normal_read_model_instance)
      allow(changes_read_model_class).to receive(:find_or_create_by).with(id: aggregate_id).and_return(changes_read_model_instance)
    end

    context 'when initialized as draft' do
      subject { draftable_aggregate_class.new(aggregate_id, draft: true) }

      before do
        allow(subject).to receive(:changes_read_model_class).and_return(changes_read_model_class)
      end

      it 'returns the changes read model' do
        expect(subject.read_model).to eq(changes_read_model_instance)
      end
      
      it 'calls find_or_create_by on changes read model class' do
        subject.read_model
        
        expect(changes_read_model_class).to have_received(:find_or_create_by).with(id: aggregate_id)
      end
    end

    context 'when not initialized as draft' do
      subject { draftable_aggregate_class.new(aggregate_id, draft: false) }

      it 'returns the normal read model' do
        expect(subject.read_model).to eq(normal_read_model_instance)
      end
      
      it 'calls find_or_create_by on normal read model class' do
        subject.read_model
        
        expect(normal_read_model_class).to have_received(:find_or_create_by).with(id: aggregate_id)
      end
    end
  end

  describe '#update_read_model' do
    let(:draft_instance) { draftable_aggregate_class.new('test-id', draft: true) }
    let(:normal_instance) { draftable_aggregate_class.new('test-id', draft: false) }
    let(:changes_read_model) { double('ChangesReadModel', update!: true) }
    let(:normal_read_model) { double('NormalReadModel', update!: true) }
    let(:changes_read_model_class) { double('ChangesReadModelClass') }
    let(:test_attributes) { { name: 'Test' } }

    before do
      allow(I18n).to receive(:with_locale).and_yield
      allow(draftable_aggregate_class).to receive(:read_model_class).and_return(OpenStruct)
      allow(OpenStruct).to receive(:find_or_create_by).with(id: 'test-id').and_return(normal_read_model)
    end

    context 'when initialized as draft' do
      before do
        # Mock the changes read model class resolution
        allow(draft_instance).to receive(:changes_read_model_class).and_return(changes_read_model_class)
        allow(changes_read_model_class).to receive(:find_or_create_by).with(id: 'test-id').and_return(changes_read_model)
        # Mock update_draft_aggregate to avoid TestContext constant error
        allow(draft_instance).to receive(:update_draft_aggregate)
      end

      it 'updates the changes read model' do
        draft_instance.update_read_model(test_attributes)
        
        aggregate_failures do
          expect(changes_read_model).to have_received(:update!).with(hash_including(test_attributes))
          expect(normal_read_model).not_to have_received(:update!)
        end
      end

      it 'calls update_draft_aggregate' do
        draft_instance.update_read_model(test_attributes)
        
        expect(draft_instance).to have_received(:update_draft_aggregate)
      end
    end

    context 'when not initialized as draft' do
      before do
        allow(normal_instance).to receive(:update_draft_aggregate)
      end

      it 'updates the normal read model' do
        normal_instance.update_read_model(test_attributes)
        
        aggregate_failures do
          expect(normal_read_model).to have_received(:update!).with(hash_including(test_attributes))
          expect(changes_read_model).not_to have_received(:update!)
        end
      end

      it 'does not call update_draft_aggregate' do
        normal_instance.update_read_model(test_attributes)
        
        expect(normal_instance).not_to have_received(:update_draft_aggregate)
      end
    end
  end

  describe 'private class methods' do
    describe '.draft_aggregate_class' do
      subject { draftable_aggregate_class }
      let(:mock_class) { double('DraftAggregateClass') }
      let(:mock_module) { Module.new }

      before do
        stub_const('TestContext::TestAggregateDraft', mock_module)
        stub_const('TestContext::TestAggregateDraft::Aggregate', mock_class)
      end

      it 'returns the constantized draft aggregate class' do
        expect(subject.send(:draft_aggregate_class)).to eq(mock_class)
      end
    end

    describe '.draft_read_model_class' do
      subject { draftable_aggregate_class }
      let(:mock_class) { double('DraftReadModelClass') }

      before do
        stub_const('::TestAggregateDraft', mock_class)
      end

      it 'returns the constantized draft read model class' do
        expect(subject.send(:draft_read_model_class)).to eq(mock_class)
      end
    end

    describe '.main_changes_model_foreign_key' do
      subject { draftable_aggregate_class }
      let(:draft_class) { double('DraftAggregateClass') }

      before do
        allow(subject).to receive(:draft_aggregate_class).and_return(draft_class)
      end

      context 'when draft aggregate class responds to changes_read_model_foreign_key' do
        before do
          allow(draft_class).to receive(:changes_read_model_foreign_key).and_return('custom_key')
        end

        it 'returns the foreign key from draft aggregate class' do
          expect(subject.send(:main_changes_model_foreign_key)).to eq('custom_key')
        end
      end

      context 'when draft aggregate class does not respond to changes_read_model_foreign_key' do
        before do
          allow(draft_class).to receive(:respond_to?).with(:changes_read_model_foreign_key).and_return(false)
        end

        it 'generates the foreign key from draft aggregate name' do
          expect(subject.send(:main_changes_model_foreign_key)).to eq('test_aggregate_change_id')
        end
      end

      context 'with custom draft aggregate ending in Batch' do
        let(:batch_class) do
          Class.new(aggregate_class) do
            draftable draft_aggregate: { aggregate: 'TestAggregateBatch' }
          end
        end
        let(:batch_draft_class) { double('BatchDraftAggregateClass') }

        before do
          allow(batch_draft_class).to receive(:respond_to?).with(:changes_read_model_foreign_key).and_return(false)
          allow(batch_class).to receive(:draft_aggregate_class).and_return(batch_draft_class)
        end

        it 'removes _batch suffix when generating foreign key' do
          expect(batch_class.send(:main_changes_model_foreign_key)).to eq('test_aggregate_change_id')
        end
      end
    end
  end

  describe '#update_draft_aggregate' do
    let(:draft_instance) { draftable_aggregate_class.new('test-id', draft: true) }
    let(:draft_read_model_class) { double('DraftReadModelClass') }
    let(:draft_read_model) { double('DraftReadModel', state_draft!: true) }
    let(:read_model) { double('ReadModel', update!: true, test_aggregate_id: 'base-id') }
    let(:test_attributes) { { name: 'Test' } }
    
    before do
      allow(draft_instance).to receive(:read_model).and_return(read_model)
      allow(I18n).to receive(:with_locale).and_yield
      stub_const('::TestAggregateDraft', draft_read_model_class)
      allow(draftable_aggregate_class).to receive(:draft_read_model_class).and_return(draft_read_model_class)
      allow(draftable_aggregate_class).to receive(:main_changes_model_foreign_key).and_return('test_aggregate_id')
    end

    context 'when read model has the foreign key method' do
      before do
        allow(read_model).to receive(:respond_to?).with(:test_aggregate_id).and_return(true)
      end

      context 'when draft read model exists' do
        before do
          allow(draft_read_model_class).to receive(:find_by).
            with('test_aggregate_id' => 'base-id').
            and_return(draft_read_model)
        end

        it 'updates the draft read model state to draft' do
          draft_instance.update_read_model(test_attributes)
          
          expect(draft_read_model).to have_received(:state_draft!)
        end
      end

      context 'when draft read model does not exist' do
        before do
          allow(draft_read_model_class).to receive(:find_by).
            with('test_aggregate_id' => 'base-id').
            and_return(nil)
        end

        it 'does not raise an error' do
          expect { draft_instance.update_read_model(test_attributes) }.not_to raise_error
        end
        
        it 'does not call state_draft!' do
          draft_instance.update_read_model(test_attributes)
          
          expect(draft_read_model).not_to have_received(:state_draft!)
        end
      end
    end

    context 'when read model does not have the foreign key method' do
      before do
        allow(read_model).to receive(:respond_to?).with(:test_aggregate_id).and_return(false)
        allow(draft_read_model_class).to receive(:find_by)
      end

      it 'does not update the draft aggregate' do
        draft_instance.update_read_model(test_attributes)
        
        expect(draft_read_model_class).not_to have_received(:find_by)
      end
    end
  end
end
