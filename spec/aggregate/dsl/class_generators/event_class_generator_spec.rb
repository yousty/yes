# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::ClassGenerators::EventClassGenerator do
  let(:generator) do
    described_class.new(
      context_name: 'Blog',
      aggregate_name: 'Post',
      attribute_name: :title,
      attribute_type: :string,
      event_name: :title_changed
    )
  end

  describe '#generate' do
    let(:generated_class) { generator.generate }

    it 'generates an event class' do
      expect(generated_class.superclass).to eq(Yes::Event)
    end

    it 'has correct event data' do
      event = generated_class.new(data: { post_id: SecureRandom.uuid, title: 'New Title' })
      expect(event.data[:title]).to eq('New Title')
    end
  end
end
