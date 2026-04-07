# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassNameConvention do
  subject(:convention) { described_class.new(context:, aggregate:) }

  let(:context) { 'Blog' }
  let(:aggregate) { 'Post' }

  describe '#class_name_for' do
    {
      command: {
        change_title: 'Blog::Post::Commands::ChangeTitle::Command',
        publish: 'Blog::Post::Commands::Publish::Command'
      },
      event: {
        title_changed: 'Blog::Post::Events::TitleChanged',
        published: 'Blog::Post::Events::Published'
      },
      guard_evaluator: {
        change_title: 'Blog::Post::Commands::ChangeTitle::GuardEvaluator',
        publish: 'Blog::Post::Commands::Publish::GuardEvaluator'
      }
    }.each do |type, examples|
      context "with #{type} type" do
        examples.each do |name, expected|
          it "generates #{expected} for #{name}" do
            expect(convention.class_name_for(type, name)).to eq(expected)
          end
        end
      end
    end
  end
end
