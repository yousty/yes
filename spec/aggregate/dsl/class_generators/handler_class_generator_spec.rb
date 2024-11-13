# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::ClassGenerators::HandlerClassGenerator do
  let(:generator) do
    described_class.new(
      context_name: 'Blog',
      aggregate_name: 'Post',
      attribute_name: :title,
      event_name: :title_changed
    )
  end

  describe '#generate' do
    let(:generated_class) { generator.generate }

    it 'generates a handler class' do
      expect(generated_class.superclass).to eq(Yes::CommandHandler)
    end

    it 'defines a call method' do
      expect(generated_class.instance_methods(false)).to include(:call)
    end

    it 'defines a validation method' do
      expect(generated_class.instance_methods(false)).to include(:check_title_is_not_changing)
    end
  end
end
