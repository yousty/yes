# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::ClassResolvers::Authorizer do
  let(:context_name) { 'TestContext' }
  let(:aggregate_name) { 'TestAggregate' }
  let(:custom_resource_name) { 'custom_resource' }
  let(:default_resource_name) { aggregate_name.underscore } # 'test_aggregate'
  let(:command_double) { instance_double(Yes::Core::Command) }
  let(:auth_data_double) { { user_id: SecureRandom.uuid } }

  # Define dummy classes needed for testing
  let!(:dummy_read_model_class) do
    stub_const("Auth::Resources::#{aggregate_name}", Class.new)
  end
  let!(:custom_dummy_read_model_class) { Class.new }
  let!(:existing_authorizer_class) { Class.new(Yousty::Eventsourcing::CommandCerbosAuthorizer) }
  let!(:base_cerbos_authorizer_class) { Yousty::Eventsourcing::CommandCerbosAuthorizer }
  let!(:base_command_authorizer_class) { Yousty::Eventsourcing::CommandAuthorizer }

  let(:generated_class) { resolver.call }
  let(:instance) { generated_class.new }
  let(:read_model_class) { nil }
  let(:resource_name) { nil }
  let(:custom_call_logic) { nil }

  let(:authorizer_options) do
    Yes::Core::Aggregate::HasAuthorizer::AuthorizerOptions.new(
      authorizer_base_class: base_authorizer_class,
      context: context_name,
      aggregate: aggregate_name,
      read_model_class: read_model_class,
      resource_name: resource_name,
      authorizer_block: custom_call_logic
    )
  end

  let(:resolver) do
    described_class.new(authorizer_options)
  end

  before do
    # Ensure the authorizer class is not defined before each test
    # This prevents state leakage between examples where one might define
    # the constant that another expects to generate.
    hide_const("#{context_name}::#{aggregate_name}::Commands::#{aggregate_name}Authorizer")

    # Allow tracking calls while letting the original method run
    allow(Yes::Core.configuration).to receive(:register_aggregate_authorizer_class).and_call_original
  end

  describe '#initialize' do
    subject { resolver }

    let(:base_authorizer_class) { base_cerbos_authorizer_class }

    context 'when read_model_class and resource_name are provided' do
      let(:read_model_class) { custom_dummy_read_model_class }
      let(:resource_name) { custom_resource_name }

      it 'initializes with the provided values' do
        aggregate_failures do
          expect(subject.send(:read_model_class)).to eq(custom_dummy_read_model_class)
          expect(subject.send(:resource_name)).to eq(custom_resource_name)
          expect(subject.send(:context_name)).to eq(context_name)
          expect(subject.send(:aggregate_name)).to eq(aggregate_name)
          expect(subject.send(:custom_call_logic)).to be_nil # No block passed
        end
      end
    end

    context 'when read_model_class and resource_name are nil' do
      it 'initializes with default values' do
        aggregate_failures do
          expect(subject.send(:read_model_class)).to eq(dummy_read_model_class)
          expect(subject.send(:resource_name)).to eq(default_resource_name)
          expect(subject.send(:context_name)).to eq(context_name)
          expect(subject.send(:aggregate_name)).to eq(aggregate_name)
          expect(subject.send(:custom_call_logic)).to be_nil # No block passed
        end
      end

      context 'when default read model class does not exist' do
        before { hide_const("Auth::Resources::#{aggregate_name}") }

        it 'raises a NameError' do
          expect { subject }.to raise_error(NameError)
        end
      end
    end

    context 'when a block is provided' do
      let(:custom_call_logic) { ->(_cmd, _auth) { true } }

      it 'stores the provided block' do
        expect(subject.send(:custom_call_logic)).to eq(custom_call_logic)
      end
    end
  end

  describe '#call' do
    subject { resolver.call }

    context 'when using CommandCerbosAuthorizer' do
      let(:base_authorizer_class) { base_cerbos_authorizer_class }

      context 'when an authorizer class already exists' do
        before do
          stub_const("#{context_name}::#{aggregate_name}::Commands::#{aggregate_name}Authorizer",
                     existing_authorizer_class)
        end

        it 'registers the existing class in the configuration' do
          subject
          expect(Yes::Core.configuration).to have_received(:register_aggregate_authorizer_class).
            with(context_name, aggregate_name, existing_authorizer_class)
        end

        it 'returns the existing class' do
          expect(subject).to eq(existing_authorizer_class)
        end
      end

      context 'when an authorizer class does not exist' do
        subject { generated_class }

        it 'generates a new authorizer class with RESOURCE constant' do
          aggregate_failures do
            expect(subject).to be_a(Class)
            expect(subject).to be < Yousty::Eventsourcing::CommandCerbosAuthorizer
            expect(subject.const_defined?(:RESOURCE)).to be true
            expect(subject::RESOURCE).to eq({ read_model: dummy_read_model_class,
                                              name: default_resource_name }.freeze)
            # Ensure call method is NOT defined dynamically for Cerbos authorizer
            expect(subject.instance_methods).not_to include(:call)
          end
        end

        it 'registers the generated class in the configuration' do
          subject
          expect(Yes::Core.configuration).to have_received(:register_aggregate_authorizer_class).
            with(context_name, aggregate_name, generated_class)
        end

        it 'returns the generated class' do
          aggregate_failures do
            expect(subject).to be_a(Class)
            expect(subject.name).to eq("#{context_name}::#{aggregate_name}::Commands::#{aggregate_name}Authorizer")
            expect(subject).to be < Yousty::Eventsourcing::CommandCerbosAuthorizer
            expect(subject.const_defined?(:RESOURCE)).to be true
            expect(subject::RESOURCE).to eq({ read_model: dummy_read_model_class,
                                              name: default_resource_name }.freeze)
          end
        end
      end

      context 'when using custom read_model_class and resource_name for generation' do
        let(:read_model_class) { custom_dummy_read_model_class }
        let(:resource_name) { custom_resource_name }

        before { subject }

        it 'generates a class with custom resource details' do
          expect(generated_class::RESOURCE).to eq({ read_model: custom_dummy_read_model_class,
                                                    name: custom_resource_name }.freeze)
        end
      end
    end

    context 'when using CommandAuthorizer (non-Cerbos)' do
      subject { generated_class }

      let(:base_authorizer_class) { base_command_authorizer_class }

      context 'when a block is provided' do
        let(:block_return_value) { double('BlockReturnValue') }
        # Define the Proc to call the helper methods `command` and `auth_data`,
        # mirroring how the user defines the block in the aggregate.
        let(:custom_block) do
          captured_value = block_return_value
          # This Proc calls the helper methods `command` and `auth_data`,
          # which are defined on the authorizer instance and read the temp ivars.
          proc { [command, auth_data, captured_value] }
        end

        let(:custom_call_logic) { custom_block }

        it 'generates a class inheriting from CommandAuthorizer without RESOURCE' do
          aggregate_failures do
            expect(subject).to be_a(Class)
            expect(subject).to be < Yousty::Eventsourcing::CommandAuthorizer
            expect(subject.const_defined?(:RESOURCE)).to be false
          end
        end

        it 'generates a class with a call method executing the block' do
          # Check if the call method exists and executes the block logic correctly
          expect(subject.new.call(command_double, auth_data_double)).to eq([command_double, auth_data_double,
                                                                            block_return_value])
        end

        it 'registers the generated class (with custom call method)' do
          aggregate_failures do
            expect(Yes::Core.configuration).to have_received(:register_aggregate_authorizer_class).
              with(context_name, aggregate_name, subject)
            expect(subject.ancestors).to include(Yousty::Eventsourcing::CommandAuthorizer)
          end
        end

        it 'returns the generated class' do
          aggregate_failures do
            expect(subject).to be_a(Class)
            expect(subject.name).to eq("#{context_name}::#{aggregate_name}::Commands::#{aggregate_name}Authorizer")
            expect(subject).to be < Yousty::Eventsourcing::CommandAuthorizer
            expect(subject.const_defined?(:RESOURCE)).to be false
            expect(subject.instance_methods).to include(:call) # call method defined
          end
        end
      end

      context 'when no block is provided' do
        it 'raises ArgumentError during call' do
          expect { resolver.call }.to raise_error(ArgumentError, /block must be provided/)
        end
      end
    end
  end

  describe '#class_type' do
    subject { resolver.send(:class_type) }

    let(:base_authorizer_class) { base_command_authorizer_class }

    it 'returns :authorizer' do
      expect(subject).to eq(:authorizer)
    end
  end
end
