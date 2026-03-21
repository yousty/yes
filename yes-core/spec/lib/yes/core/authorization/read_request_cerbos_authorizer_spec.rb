# frozen_string_literal: true

RSpec.describe Yes::Core::Authorization::ReadRequestCerbosAuthorizer do
  describe '.call' do
    subject { authorizer_class.call(params, auth_data) }

    let(:authorizer_class) { described_class }

    let(:auth_data) { { identity_id: } }
    let(:identity_id) { SecureRandom.uuid }
    let(:company_id) { SecureRandom.uuid }

    let(:principal) { OpenStruct.new(id: SecureRandom.uuid, identity_id:, role_ids:) }
    let(:role_ids) { [] }

    let(:params) { { model:, filters: { company_ids: filters_company_ids } } }
    let(:model) { 'apprenticeships' }

    let(:filters_company_ids) { managed_company_ids.join(',') }
    let(:managed_company_ids) { [company_id] }

    let(:cerbos_client) { instance_double(Cerbos::Client) }
    let(:cerbos_class) { Cerbos::Client }
    let(:cerbos_decision_output) { [double('CerbosDecisionOutput', value: 'example_output')] }
    let(:cerbos_decision) { instance_double('CerbosDecision', allow_all?: true, outputs: cerbos_decision_output) }

    let(:actions) { Yes::Core.configuration.cerbos_read_authorizer_actions }

    let(:authorization_payload) do
      {
        principal: {
          id: identity_id,
          roles: cerbos_roles,
          attributes: { read_resource_access: {} }
        },
        resource: {
          scope: instance_of(String),
          kind: model,
          id: "#{Yes::Core.configuration.cerbos_read_authorizer_resource_id_prefix}#{model}",
          attributes: {}
        },
        actions:,
        include_metadata: Yes::Core.configuration.cerbos_read_authorizer_include_metadata
      }
    end
    let(:cerbos_roles) { Yes::Core::Auth::Principals::User::NO_AUTHORIZATION_ROLES_YET }

    before do
      Yes::Core.configuration.cerbos_url = 'localhost:3592'
      Yes::Core.configuration.cerbos_read_authorizer_actions = %w[read]
      Yes::Core.configuration.cerbos_read_authorizer_include_metadata = true
      Yes::Core.configuration.cerbos_read_authorizer_resource_id_prefix = 'read-'
      Yes::Core.configuration.cerbos_principal_data_builder = lambda { |auth_data|
        { id: auth_data[:identity_id], roles: cerbos_roles, attributes: { read_resource_access: {} } }
      }

      allow(cerbos_class).to receive(:new).and_return(cerbos_client)
      allow(cerbos_client).to receive(:check_resource).with(authorization_payload).and_return(cerbos_decision)

      allow(authorizer_class).to receive(:check_authorization_data).and_return(true)
    end

    shared_examples 'authorization with cerbos service' do
      it 'calls cerbos client' do
        subject

        expect(cerbos_client).to have_received(:check_resource).with(authorization_payload)
      end

      context 'when authorized' do
        let(:cerbos_decision) { instance_double('CerbosDecision', allow_all?: true, outputs: cerbos_decision_output) }

        it { is_expected.to be(true) }
      end

      context 'when unauthorized' do
        let(:cerbos_decision) { instance_double('CerbosDecision', allow_all?: false, outputs: cerbos_decision_output) }

        it 'raises NotAuthorized error' do
          expect { subject }.to(
            raise_error(Yes::Core::Authorization::ReadRequestAuthorizer::NotAuthorized).with_message(
              "You don't have access to these #{model}"
            )
          )
        end
      end
    end

    context 'when super admin' do
      let(:cerbos_roles) { [Yes::Core::Auth::Principals::Role::SUPER_ADMIN_ROLE_NAME] }

      around do |example|
        original = Yes::Core.configuration.super_admin_check
        Yes::Core.configuration.super_admin_check = ->(_auth_data) { true }
        example.run
        Yes::Core.configuration.super_admin_check = original
      end

      it 'does not check authorization data' do
        subject

        expect(authorizer_class).to_not have_received(:check_authorization_data)
      end

      it_behaves_like 'authorization with cerbos service'
    end

    context 'when not super admin' do
      it 'checks authorization data' do
        subject

        expect(authorizer_class).to have_received(:check_authorization_data).with(params)
      end

      it_behaves_like 'authorization with cerbos service'

      context 'when authorization data not implemented' do
        before do
          allow(authorizer_class).to receive(:check_authorization_data).and_call_original
        end

        it 'raises NotImplementedError error' do
          expect { subject }.to(
            raise_error(
              NotImplementedError,
              'You need to implement check_authorization_data'
            )
          )
        end

        it 'does not call cerbos client' do
          expect(cerbos_client).to_not have_received(:check_resource)
        end
      end

      context 'when authorization data raise error' do
        before do
          allow(authorizer_class).to receive(:check_authorization_data).and_raise(StandardError)
        end

        it 'raises StandardError error' do
          expect { subject }.to(raise_error(StandardError))
        end

        it 'does not call cerbos client' do
          expect(cerbos_client).to_not have_received(:check_resource)
        end
      end
    end
  end
end
