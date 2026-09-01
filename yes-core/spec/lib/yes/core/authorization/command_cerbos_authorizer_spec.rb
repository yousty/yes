# frozen_string_literal: true

RSpec.describe Yes::Core::Authorization::CommandCerbosAuthorizer do
  describe '.call' do
    subject { described_class.call(command, auth_data) }

    let(:auth_data) { { identity_id: } }
    let(:identity_id) { SecureRandom.uuid }

    let(:principal) { OpenStruct.new(id: SecureRandom.uuid, identity_id:, role_ids: []) }

    let(:command) { Dummy::User::Commands::ChangeFirstName::Command.new(name:, id:, company_id:) }
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

  describe '.call inside a LookupCache scope' do
    subject do
      Yes::Core::Authorization::LookupCache.with_scope do
        commands.each { described_class.call(_1, auth_data) }
      end
    end

    let(:auth_data) { { identity_id: } }
    let(:identity_id) { SecureRandom.uuid }

    let(:company_id) { SecureRandom.uuid }
    let(:commands) do
      Array.new(3) do
        Dummy::User::Commands::ChangeFirstName::Command.new(
          name: SecureRandom.hex(4), id: SecureRandom.uuid, company_id:
        )
      end
    end

    let(:resource_const) { { name: 'company', read_model: resource_read_model } }
    let(:resource_read_model) { double('CompanyModel') }
    let(:resource) { double('Company', id: SecureRandom.uuid) }

    let(:cerbos_client) { instance_double(Cerbos::Client) }
    let(:cerbos_decision) { instance_double('CerbosDecision', allow_all?: true) }

    let(:principal_data_builder_calls) { [] }
    let(:cerbos_payloads) { [] }

    around do |example|
      original_builder = Yes::Core.configuration.cerbos_principal_data_builder
      Yes::Core.configuration.cerbos_principal_data_builder = lambda { |data|
        principal_data_builder_calls << data[:identity_id]
        { id: data[:identity_id], roles: [], attributes: { write_resource_access: {} } }
      }
      example.run
      Yes::Core.configuration.cerbos_principal_data_builder = original_builder
    end

    before do
      stub_const('Yes::Core::Authorization::CommandCerbosAuthorizer::RESOURCE', resource_const)
      allow(Cerbos::Client).to receive(:new).and_return(cerbos_client)
      allow(cerbos_client).to receive(:check_resource) do |**kwargs|
        cerbos_payloads << kwargs
        cerbos_decision
      end
      allow(resource_read_model).to receive(:find_by).and_return(resource)
    end

    it 'builds the principal data once and loads the shared resource once' do
      subject

      aggregate_failures do
        expect(principal_data_builder_calls).to eq([identity_id])
        expect(resource_read_model).to have_received(:find_by).once
        expect(cerbos_payloads.size).to eq(commands.size)
      end
    end

    it 'still authorizes every command against Cerbos with its own payload' do
      subject

      sent_payloads = cerbos_payloads.map { _1[:principal][:attributes][:command_payload] }

      expect(sent_payloads).to eq(commands.map { _1.payload.deep_symbolize_keys })
    end

    context 'when the commands target different resources' do
      let(:commands) do
        Array.new(2) do
          Dummy::User::Commands::ChangeFirstName::Command.new(
            name: SecureRandom.hex(4), id: SecureRandom.uuid, company_id: SecureRandom.uuid
          )
        end
      end

      it 'loads each resource separately' do
        subject

        aggregate_failures do
          expect(resource_read_model).to have_received(:find_by).twice
          expect(principal_data_builder_calls).to eq([identity_id])
        end
      end
    end

    context 'when no scope is open' do
      subject { commands.each { described_class.call(_1, auth_data) } }

      it 'resolves the principal and the resource per command' do
        subject

        aggregate_failures do
          expect(principal_data_builder_calls).to eq([identity_id] * commands.size)
          expect(resource_read_model).to have_received(:find_by).exactly(commands.size).times
        end
      end
    end
  end
end
