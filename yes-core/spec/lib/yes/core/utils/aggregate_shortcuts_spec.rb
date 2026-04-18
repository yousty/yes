# frozen_string_literal: true

RSpec.describe Yes::Core::Utils::AggregateShortcuts do
  # Names that are highly unlikely to clash with anything else loaded in the
  # test process. Each example that defines a top-level shortcut module under
  # one of these names is responsible for cleaning it up in `after`.
  let(:context_abbrs) { %w[ZX1Ctx ZX2Ctx] }

  before do
    described_class.instance_variable_set(:@context_overrides, {})
    described_class.instance_variable_set(:@subject_overrides, {})
    described_class.instance_variable_set(:@aggregates, [])
    described_class.instance_variable_set(:@shortcuts, {})
  end

  after do
    context_abbrs.each do |name|
      Object.send(:remove_const, name) if Object.const_defined?(name, false)
    end
  end

  describe '#abbreviate_subject (private)' do
    subject(:abbreviate) { described_class.send(:abbreviate_subject, name) }

    context 'with multiple capital letters' do
      let(:name) { 'ContactInfo' }

      it 'returns the capitals-only abbreviation' do
        expect(abbreviate).to eq('CI')
      end
    end

    context 'with three capital letters' do
      let(:name) { 'CustomResourceItem' }

      it 'returns all the capitals' do
        expect(abbreviate).to eq('CRI')
      end
    end

    context 'with a single capital and a long name' do
      let(:name) { 'Location' }

      it 'returns the full subject name (no 4-char truncation)' do
        expect(abbreviate).to eq('Location')
      end
    end

    context 'with a single capital and a 5-char name (regression: was "Boar")' do
      let(:name) { 'Board' }

      it 'returns the full subject name' do
        expect(abbreviate).to eq('Board')
      end
    end

    context 'with a single capital and a 4-char name (regression: silently dropped)' do
      let(:name) { 'Task' }

      it 'returns the full subject name' do
        expect(abbreviate).to eq('Task')
      end
    end

    context 'when an override is configured for the subject' do
      let(:name) { 'Board' }

      before do
        described_class.instance_variable_set(:@subject_overrides, { 'Board' => 'Brd' })
      end

      it 'uses the override instead of the auto-abbreviation' do
        expect(abbreviate).to eq('Brd')
      end
    end
  end

  describe '#abbreviate_context (private)' do
    subject(:abbreviate) { described_class.send(:abbreviate_context, name) }

    context 'with multiple capital letters' do
      let(:name) { 'ApprenticeshipPresentation' }

      it 'returns the capitals-only abbreviation' do
        expect(abbreviate).to eq('AP')
      end
    end

    context 'when an override is configured for the context' do
      let(:name) { 'TaskFlow' }

      before do
        described_class.instance_variable_set(:@context_overrides, { 'TaskFlow' => 'Tflow' })
      end

      it 'uses the override' do
        expect(abbreviate).to eq('Tflow')
      end
    end
  end

  describe '#create_shortcuts (private)' do
    let(:zx1_ctx) { context_abbrs[0] }
    let(:aggregate_a) { Class.new(Yes::Core::Aggregate) }
    let(:aggregate_b) { Class.new(Yes::Core::Aggregate) }

    before do
      described_class.instance_variable_set(:@aggregates, [
                                              {
                                                context: 'TaskFlow',
                                                subject: 'Board',
                                                class: aggregate_a,
                                                class_name: 'TaskFlow::Board::Aggregate'
                                              },
                                              {
                                                context: 'TaskFlow',
                                                subject: 'Task',
                                                class: aggregate_b,
                                                class_name: 'TaskFlow::Task::Aggregate'
                                              }
                                            ])
      described_class.instance_variable_set(:@context_overrides, { 'TaskFlow' => zx1_ctx })
    end

    it 'creates a shortcut for every aggregate (regression: Task was being skipped)' do
      described_class.send(:create_shortcuts)

      expect(described_class.list).to eq(
        "#{zx1_ctx}::Board" => 'TaskFlow::Board::Aggregate',
        "#{zx1_ctx}::Task" => 'TaskFlow::Task::Aggregate'
      )
    end

    it 'assigns the aggregate classes onto a fresh container module, not the real context' do
      described_class.send(:create_shortcuts)

      shortcut_module = Object.const_get(zx1_ctx)

      aggregate_attrs = aggregate_attrs_of(shortcut_module)
      expect(aggregate_attrs).to include(
        is_module: true,
        equal_to_taskflow: false,
        board: aggregate_a,
        task: aggregate_b
      )
    end

    context 'when two subjects abbreviate to the same name' do
      let(:zx2_ctx) { context_abbrs[1] }

      before do
        described_class.instance_variable_set(:@aggregates, [
                                                {
                                                  context: 'TaskFlow',
                                                  subject: 'ContactInfo',
                                                  class: aggregate_a,
                                                  class_name: 'TaskFlow::ContactInfo::Aggregate'
                                                },
                                                {
                                                  context: 'TaskFlow',
                                                  subject: 'CustomerInteraction',
                                                  class: aggregate_b,
                                                  class_name: 'TaskFlow::CustomerInteraction::Aggregate'
                                                }
                                              ])
        described_class.instance_variable_set(:@context_overrides, { 'TaskFlow' => zx2_ctx })
        allow(Rails.logger).to receive(:warn)
      end

      it 'logs a warning and only registers the first one' do
        described_class.send(:create_shortcuts)

        expect(described_class.list).to eq("#{zx2_ctx}::CI" => 'TaskFlow::ContactInfo::Aggregate')
        expect(Rails.logger).to have_received(:warn).with(/CI already defined/)
      end
    end
  end

  def aggregate_attrs_of(shortcut_module)
    {
      is_module: shortcut_module.is_a?(Module) && !shortcut_module.is_a?(Class),
      equal_to_taskflow: defined?(TaskFlow) ? shortcut_module.equal?(TaskFlow) : false,
      board: shortcut_module.const_get(:Board),
      task: shortcut_module.const_get(:Task)
    }
  end
end
