# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate do
  describe 'HasAuthorizer concern' do
    let(:resolved_class) { aggregate_class.authorizer_class }

    context 'for Test::User::Aggregate (uses CommandAuthorizer with block)' do
      let(:aggregate_class) { Test::User::Aggregate }
      let(:expected_base_class) { Yes::Core::Authorization::CommandAuthorizer }

      it 'sets the correct authorizer class after loading' do
        aggregate_failures do
          expect(resolved_class).to be_a(Class)
          expect(resolved_class).to be < expected_base_class
          # Check if the dynamically generated class has the expected name (optional but good)
          expect(resolved_class.name).to eq('Test::User::Commands::UserAuthorizer')
        end
      end

      context 'when calling the generated authorizer' do
        let(:resolved_class) { aggregate_class.authorizer_class }
        let(:authorizer_instance) { resolved_class.new }
        let(:user_id) { SecureRandom.uuid }
        # Command object needs to respond to `user_id`
        let(:command_matching) { double('Command', user_id:) }
        let(:command_mismatch) { double('Command', user_id: SecureRandom.uuid) }
        let(:auth_data) { { user_id: } }

        it 'executes the defined block logic' do
          aggregate_failures do
            expect(authorizer_instance.call(command_matching, auth_data)).to be true
            expect(authorizer_instance.call(command_mismatch, auth_data)).to be false
          end
        end
      end
    end

    context 'for Universe::Star::Aggregate (uses CommandCerbosAuthorizer)' do
      let(:aggregate_class) { Universe::Star::Aggregate }
      let(:expected_base_class) { Yes::Core::Authorization::CommandCerbosAuthorizer }
      let(:expected_read_model_class) { Apprenticeship }

      it 'sets the correct authorizer class after loading' do
        aggregate_failures do
          expect(resolved_class).to be_a(Class)
          expect(resolved_class).to be < expected_base_class
          # Check if the dynamically generated class has the expected name
          expect(resolved_class.name).to eq('Universe::Star::Commands::StarAuthorizer')
          # Check the RESOURCE constant for Cerbos authorizer
          expect(resolved_class.const_defined?(:RESOURCE)).to be true
          # Compare class names to avoid object identity issues
          expect(resolved_class::RESOURCE[:read_model].name).to eq(expected_read_model_class.name)
          expect(resolved_class::RESOURCE[:name]).to eq('star')
        end
      end
    end

    context 'for Test::CustomResource::Aggregate (uses CommandCerbosAuthorizer with custom parameters)' do
      let(:aggregate_class) { Test::CustomResource::Aggregate }
      let(:expected_base_class) { Yes::Core::Authorization::CommandCerbosAuthorizer }
      let(:expected_read_model_class) { CustomResourceReadModel }
      let(:expected_resource_name) { 'special_resource' }

      it 'sets the correct authorizer class after loading with custom read_model_class and resource_name' do
        aggregate_failures do
          expect(resolved_class).to be_a(Class)
          expect(resolved_class).to be < expected_base_class
          # Check if the dynamically generated class has the expected name
          expect(resolved_class.name).to eq('Test::CustomResource::Commands::CustomResourceAuthorizer')
          # Check the RESOURCE constant for Cerbos authorizer
          expect(resolved_class.const_defined?(:RESOURCE)).to be true
          # Verify the custom read_model_class was used
          expect(resolved_class::RESOURCE[:read_model].name).to eq(expected_read_model_class.name)
          # Verify the custom resource_name was used
          expect(resolved_class::RESOURCE[:name]).to eq(expected_resource_name)
        end
      end
    end

    # Consider a test for an aggregate *without* authorize defined
    context 'for an aggregate without explicit authorization (Test::Location::Aggregate)' do
      let(:aggregate_class) { Test::Location::Aggregate }

      it 'authorizer_class is nil' do
        # Test::Location::Aggregate does not call authorize, so setup should not define an authorizer
        expect(aggregate_class.authorizer_class).to be_nil
      end
    end
  end
end
