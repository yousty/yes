# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command do
  describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command::AuthorizerFactory do
    it 'creates SimpleAuthorizer for non-Cerbos aggregate authorizers' do
      cmd_data = double('CommandData',
                        aggregate_class: Test::User::Aggregate,
                        context_name: 'test',
                        aggregate_name: 'user',
                        command_name: 'approve_documents')

      resolver = described_class.create(cmd_data)
      expect(resolver).to be_a(Yes::Core::Aggregate::Dsl::ClassResolvers::Command::SimpleAuthorizer)
    end

    it 'creates CerbosAuthorizer for Cerbos-based aggregate authorizers' do
      cmd_data = double('CommandData',
                        aggregate_class: Universe::Star::Aggregate,
                        context_name: 'universe',
                        aggregate_name: 'star',
                        command_name: 'test')

      resolver = described_class.create(cmd_data)
      expect(resolver).to be_a(Yes::Core::Aggregate::Dsl::ClassResolvers::Command::CerbosAuthorizer)
    end

    it 'returns nil when aggregate has no authorizer' do
      cmd_data = double('CommandData',
                        aggregate_class: double('AggregateClass', authorizer_class: nil),
                        context_name: 'test',
                        aggregate_name: 'missing',
                        command_name: 'test')

      resolver = described_class.create(cmd_data)
      expect(resolver).to be_nil
    end
  end

  describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command::SimpleAuthorizer do
    subject(:authorizer_class) do
      Yes::Core.configuration.aggregate_class('Test', 'User', :approve_documents, :authorizer)
    end

    it 'is registered and inherits from the simple aggregate authorizer' do
      aggregate_class_authorizer = Test::User::Aggregate.authorizer_class

      aggregate_failures do
        expect(authorizer_class).to be < aggregate_class_authorizer
        expect(authorizer_class.name).to eq('Test::User::Commands::ApproveDocuments::Authorizer')
        expect(authorizer_class).not_to be < Yousty::Eventsourcing::CommandCerbosAuthorizer
      end
    end

    context 'with block' do
      let(:instance) { authorizer_class.new }
      let(:cmd) { double('Command', another: name) }
      let(:name) { 'John' }

      it 'executes the simple authorizer block correctly' do
        aggregate_failures do
          expect(instance.call(cmd, { name: })).to be true
          expect(instance.call(cmd, { name: 'Jane' })).to be false
        end
      end
    end
  end

  describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command::CerbosAuthorizer do
    subject(:cerbos_authorizer_class) do
      Yes::Core.configuration.aggregate_class('Universe', 'Star', :create_star, :authorizer)
    end

    let(:command_obj) { double('Command') }
    let(:resource) { double('Resource') }

    it 'inherits from CommandCerbosAuthorizer' do
      # Test that the authorizer is a CerbosAuthorizer
      expect(Universe::Star::Aggregate.authorizer_class).to be < Yousty::Eventsourcing::CommandCerbosAuthorizer
    end

    context 'resource_attributes' do
      subject { cerbos_authorizer_class.resource_attributes(resource, command_obj) }

      it 'returns custom resource_attributes' do
        expect(subject).to include(owner_id: 'test-user-id')
      end
    end

    context 'cerbos_payload' do
      subject { cerbos_authorizer_class.cerbos_payload(command_obj, resource, auth_data) }
      let(:auth_data) { { user_id: 'auth-user-id' } }

      it 'returns custom cerbos_payload' do
        expect(subject).to include(
          principal: auth_data,
          resource_id: 'test-id'
        )
      end
    end
  end

  describe Yes::Core::Aggregate::Dsl::ClassResolvers::Command::Authorizer do
    let(:cmd_data) do
      double('CommandData',
             name: 'TestCommand',
             context_name: 'test',
             aggregate_name: 'user',
             command_name: 'test_command',
             aggregate_class: double('AggregateClass', authorizer_class: nil))
    end

    subject(:authorizer) { described_class.new(cmd_data) }

    it 'returns :authorizer as class_type' do
      expect(authorizer.class_type).to eq(:authorizer)
    end

    it 'returns command name as class_name' do
      expect(authorizer.class_name).to eq('TestCommand')
    end

    it 'raises NotImplementedError for generate_class' do
      expect { authorizer.generate_class }.to raise_error(NotImplementedError)
    end
  end
end
