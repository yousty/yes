# frozen_string_literal: true

RSpec.describe Yes::Aggregate::DSL::ConstantResolver do
  subject(:resolver) { described_class.new(class_name_convention) }

  let(:class_name_convention) { instance_double(Yes::Aggregate::DSL::ClassNameConvention) }

  before do
    allow(class_name_convention).to receive(:class_name_for).
      with(:command, :change_title).
      and_return('Blog::Post::Commands::ChangeTitle')
  end

  describe '#find_conventional_class' do
    subject { resolver.find_conventional_class(:command, :change_title) }
    
    context 'when class exists' do
      before do
        stub_const('Blog::Post::Commands::ChangeTitle', Class.new)
      end

      it 'returns the class' do
        expect(subject).to eq(Blog::Post::Commands::ChangeTitle)
      end
    end

    context 'when class does not exist' do
      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  describe '#set_constant_for' do
    subject { resolver.set_constant_for(:command, :change_title, test_class) }

    let(:test_class) { Class.new }

    after do
      Object.send(:remove_const, :Blog) if Object.const_defined?(:Blog)
    end

    it 'creates module hierarchy and sets the constant' do
      expect(subject).to eq(test_class)
      expect(Blog::Post::Commands::ChangeTitle).to eq(test_class)
    end
  end
end
