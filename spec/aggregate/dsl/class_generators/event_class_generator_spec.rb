# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::ClassGenerators::EventClassGenerator do
  subject(:generated_class) { generator.generate }

  let(:generator) do
    described_class.new(
      context_name: 'Blog',
      aggregate_name: 'Post',
      attribute_name: :title,
      attribute_type: :string,
      event_name: :title_changed
    )
  end

  after do
    Object.send(:remove_const, :Blog) if Object.const_defined?(:Blog)
  end

  describe '#generate' do
    it 'generates an event class' do
      expect(generated_class.superclass).to eq(Yes::Event)
    end

    it 'has correct event data' do
      event = generated_class.new(data: { post_id: SecureRandom.uuid, title: 'New Title' })
      expect(event.data[:title]).to eq('New Title')
    end
  end
end
