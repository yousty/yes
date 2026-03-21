# frozen_string_literal: true

RSpec.describe Yes::Core::Authorization::CommandCerbosAuthorizer do
  describe '.call' do
    subject { described_class.call(command, auth_data) }

    let(:auth_data) { { identity_id: } }
    let(:identity_id) { SecureRandom.uuid }

    let(:principal) { OpenStruct.new(id: SecureRandom.uuid, identity_id:, role_ids: []) }

    let(:command) { Dummy::Commands::User::ChangeFirstName.new(name:, id: , company_id: ) }
    let(:name) { 'name' }
    let(:id) { SecureRandom.uuid }
    let(:company_id) { SecureRandom.uuid }

    let(:resource_const) { { name: resource_name, read_model: resource_read_model } }
    let(:resource_name) { 'company' }
    let(:resource_read_model) { double('UserModel') }
    let(:resource) { double('User') }

    let(:resource_id) { SecureRandom.uuid }

    let(:cerbos_client) { instance_double(Cerbos::Client) }
    let(:cerbos_class) { Cerbos::Client }
    let(:cerbos_decision) { instance_double('CerbosDecision', allow_all?: false) }

    around do |example|
      original_builder = Yes::Core.configuration.cerbos_principal_data_builder
      Yes::Core.configuration.cerbos_principal_data_builder = lambda { |auth_data|
        {
          id: auth_data[:identity_id],
          roles: Yes::Core::Auth::Principals::User::NO_AUTHORIZATION_ROLES_YET,
          attributes: { write_resource_access: {} }
        }
      }
      example.run
      Yes::Core.configuration.cerbos_principal_data_builder = original_builder
    end

    before do
      allow(cerbos_class).to receive(:new).and_return(cerbos_client)
      allow(cerbos_client).to receive(:check_resource).with(
        principal: {
          id: identity_id,
          roles: Yes::Core::Auth::Principals::User::NO_AUTHORIZATION_ROLES_YET,
          attributes: {
            write_resource_access: {},
            command_payload: {
              company_id:,
              id:,
              name:
            }
          }
        },
        resource: {
          kind: resource_name,
          scope: 'dummy',
          id: resource_id,
          attributes: {}
        },
        actions: ['change_first_name'],
        include_metadata: Yes::Core.configuration.cerbos_commands_authorizer_include_metadata
      ).and_return(cerbos_decision)

      allow(resource).to receive(:id).and_return(resource_id)
    end

    context 'when identity id is not present' do
      let(:auth_data) { {} }

      before do
        allow(resource_read_model).to receive(:find_by).with(id: command.company_id).and_return(resource)
      end

      it 'raises CommandNotAuthorized error' do
        expect { subject }.to(
          raise_error(
            Yes::Core::Authorization::CommandAuthorizer::CommandNotAuthorized,
            'Missing identity id in JWT token auth_data'
          )
        )
      end
    end

    context 'when RESOURCE const is not defined at all' do
      before do
        allow(resource_read_model).to receive(:find_by).with(id: command.company_id).and_return(resource)
      end

      it 'raises StandardError' do
        expect { subject }.to raise_error(
          StandardError,
          'Your CommandCerbosAuthorizer subclass needs to define RESOURCE[:name] and RESOURCE[:read_model] constant'
        )
      end
    end

    context 'when some part of the const definition is missing' do
      before do
        stub_const('Yes::Core::Authorization::CommandCerbosAuthorizer::RESOURCE', resource_const)
      end

      context 'when RESOURCE[:name] const is not defined' do
        let(:resource_name) { nil }

        before do
          allow(resource_read_model).to receive(:find_by).with(id: command.company_id).and_return(resource)
        end

        it 'raises StandardError' do
          expect { subject }.to raise_error(
            StandardError,
            'Your CommandCerbosAuthorizer subclass needs to define RESOURCE[:name] and RESOURCE[:read_model] constant'
          )
        end
      end

      context 'when RESOURCE[:read_model] const is not defined' do
        let(:resource_read_model) { nil }

        it 'raises StandardError' do
          expect { subject }.to raise_error(
            StandardError,
            'Your CommandCerbosAuthorizer subclass needs to define RESOURCE[:name] and RESOURCE[:read_model] constant'
          )
        end
      end
    end

    context 'when authorized' do
      let(:cerbos_decision) { instance_double('CerbosDecision', allow_all?: true) }

      before do
        stub_const('Yes::Core::Authorization::CommandCerbosAuthorizer::RESOURCE', resource_const)
        allow(resource_read_model).to receive(:find_by).with(id: command.company_id).and_return(resource)
      end

      it 'returns true' do
        expect(subject).to be true
      end
    end

    context 'when unauthorized' do
      let(:cerbos_decision) { instance_double('CerbosDecision', allow_all?: false, outputs: {}) }

      before do
        stub_const('Yes::Core::Authorization::CommandCerbosAuthorizer::RESOURCE', resource_const)
        allow(resource_read_model).to receive(:find_by).with(id: command.company_id).and_return(resource)
      end

      it 'raises CommandNotAuthorized error' do
        expect { subject }.to(
          raise_error(
            Yes::Core::Authorization::CommandAuthorizer::CommandNotAuthorized
          )
        )
      end
    end
  end
end
