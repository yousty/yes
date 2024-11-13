# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::ConstantResolver do
  let(:class_name_convention) { instance_double(Yes::Aggregate::DSL::ClassNameConvention) }
  let(:resolver) { described_class.new(class_name_convention) }

  describe '#find_conventional_class' do
    before do
      allow(class_name_convention).to receive(:class_name_for).
        with(:command, :change_title).
        and_return('Blog::Post::Commands::ChangeTitle')
    end

    context 'when class exists' do
      before do
        stub_const('Blog::Post::Commands::ChangeTitle', Class.new)
      end

      it 'returns the class' do
        expect(resolver.find_conventional_class(:command, :change_title)).
          to eq(Blog::Post::Commands::ChangeTitle)
      end
    end

    context 'when class does not exist' do
      it 'returns nil' do
        expect(resolver.find_conventional_class(:command, :change_title)).to be_nil
      end
    end
  end

  describe '#set_constant_for' do
    let(:test_class) { Class.new }

    before do
      allow(class_name_convention).to receive(:class_name_for).
        with(:command, :change_title).
        and_return('Test::Commands::ChangeTitle')
    end

    after do
      Object.send(:remove_const, :Test) if Object.const_defined?(:Test)
    end

    it 'creates module hierarchy and sets the constant' do
      result = resolver.set_constant_for(:command, :change_title, test_class)

      expect(result).to eq(test_class)
      expect(Test::Commands::ChangeTitle).to eq(test_class)
    end
  end
end
