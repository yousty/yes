# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Yes::Core::Aggregate::Dsl::AttributeDefiners::Base do
  subject(:definer) { described_class.new(attribute_data) }

  let(:attribute_data) { instance_double('Yes::Core::Aggregate::Dsl::AttributeData') }

  describe '#call' do
    before do
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Command).to receive(:new).and_return(command_resolver)
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Event).to receive(:new).and_return(event_resolver)
      allow(Yes::Core::Aggregate::Dsl::ClassResolvers::Handler).to receive(:new).and_return(handler_resolver)
    end

    let(:command_resolver) { instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Command', call: true) }
    let(:event_resolver) { instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Event', call: true) }
    let(:handler_resolver) { instance_double('Yes::Core::Aggregate::Dsl::ClassResolvers::Handler', call: true) }

    it 'defines classes using the class resolvers' do
      expect { definer.call }.to raise_error(NotImplementedError)

      expect(command_resolver).to have_received(:call)
      expect(event_resolver).to have_received(:call)
      expect(handler_resolver).to have_received(:call)
    end

    it 'requires subclasses to implement define_methods' do
      expect { definer.call }.to raise_error(NotImplementedError, /must implement #define_methods/)
    end
  end
end
