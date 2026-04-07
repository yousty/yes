# frozen_string_literal: true

RSpec.describe Yes::Core::CommandHandling::AggregateTracker do
  subject(:tracker) { described_class.new }

  describe '#track' do
    let(:id) { 'test-123' }
    let(:revision) { 42 }
    let(:context) { 'TestContext' }
    let(:attribute_name) { :user }

    it 'adds the aggregate to the tracked list' do
      tracker.track(attribute_name:, id:, revision:, context:)

      expect(tracker.accessed_external_aggregates).to include(
        hash_including(
          id: 'test-123',
          context: 'TestContext',
          name: 'User',
          revision: 42
        )
      )
    end
  end

  describe '#accessed_external_aggregates' do
    it 'returns an empty array by default' do
      expect(tracker.accessed_external_aggregates).to eq([])
    end

    it 'returns tracked aggregates in order of tracking' do
      tracker.track(attribute_name: :user, id: 'test-1', revision: 1, context: 'Context1')
      tracker.track(attribute_name: :company, id: 'test-2', revision: 2, context: 'Context2')

      expect(tracker.accessed_external_aggregates).to eq(
        [
          {
            id: 'test-1',
            context: 'Context1',
            name: 'User',
            revision: 1
          },
          {
            id: 'test-2',
            context: 'Context2',
            name: 'Company',
            revision: 2
          }
        ]
      )
    end
  end
end
