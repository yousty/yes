# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::ClassGenerators::CommandClassGenerator do
  let(:generator) do
    described_class.new(
      context_name: 'Blog',
      aggregate_name: 'Post',
      attribute_name: :title,
      attribute_type: :string
    )
  end

  describe '#generate' do
    let(:generated_class) { generator.generate }
    let(:command) { generated_class.new(post_id: SecureRandom.uuid, title: 'Test Title') }

    it 'generates a command class' do
      expect(generated_class.superclass).to eq(Yes::Command)
    end

    it 'includes correct attributes' do
      expect(generated_class.schema.key?(:title)).to be true
      expect(command.respond_to?(:title)).to be true
    end
  end
end
