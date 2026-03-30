# frozen_string_literal: true

RSpec.describe 'CerbosAuthorizer usage', type: :request do
  include_context :request_header_variables

  subject do
    post '/commands', params: { commands: [command_attrs] }, headers: request_headers, as: :json
  end

  let(:identity_id) { SecureRandom.uuid }
  let(:access_token) { Base64.strict_encode64({ identity_id: }.to_json) }

  let(:star_id) { SecureRandom.uuid }
  let!(:apprenticeship) { Apprenticeship.create!(id: star_id, name: 'Test Star') }

  let(:command_attrs) do
    {
      subject: 'Star',
      context: 'Universe',
      command: 'CreateStar',
      data: { star_id:, label: 'Sirius', size: 10 }
    }
  end

  let(:cerbos_client) { instance_double(Cerbos::Client) }

  around do |example|
    config = Yes::Core.configuration
    original_auth_adapter = config.auth_adapter
    original_cerbos_url = config.cerbos_url
    original_process_commands_inline = config.process_commands_inline
    original_cerbos_principal_data_builder = config.cerbos_principal_data_builder

    config.auth_adapter = DummyAuthAdapter.new
    config.cerbos_url = 'localhost:3592'
    config.process_commands_inline = true
    config.cerbos_principal_data_builder = lambda { |auth_data|
      {
        id: auth_data[:identity_id],
        roles: Yes::Core::Auth::Principals::User::NO_AUTHORIZATION_ROLES_YET,
        attributes: { write_resource_access: {} }
      }
    }

    example.run
  ensure
    config.auth_adapter = original_auth_adapter
    config.cerbos_url = original_cerbos_url
    config.process_commands_inline = original_process_commands_inline
    config.cerbos_principal_data_builder = original_cerbos_principal_data_builder
  end

  before do
    allow(Cerbos::Client).to receive(:new).and_return(cerbos_client)
  end

  context 'when command is authorized' do
    let(:cerbos_decision) { instance_double('CerbosDecision', allow_all?: true) }

    before do
      allow(cerbos_client).to receive(:check_resource).and_return(cerbos_decision)

      # Mock the command bus to avoid full aggregate execution (event store, etc.)
      command_bus = instance_double(Yes::Core::Commands::Bus)
      allow(Yes::Core::Commands::Bus).to receive(:new).and_return(command_bus)
      allow(command_bus).to receive(:call).and_return(
        [Yes::Core::Commands::Response.new(
          cmd: Universe::Star::Commands::CreateStar::Command.new(star_id:, label: 'Sirius', size: 10)
        )]
      )
    end

    it 'returns success response' do
      subject

      expect(response).to have_http_status(:ok)
    end

    it 'calls cerbos client for authorization' do
      subject

      expect(cerbos_client).to have_received(:check_resource)
    end
  end

  context 'when command is unauthorized' do
    let(:cerbos_decision) { instance_double('CerbosDecision', allow_all?: false, outputs: {}) }

    before do
      allow(cerbos_client).to receive(:check_resource).and_return(cerbos_decision)
    end

    it 'returns unauthorized response' do
      subject

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns error details' do
      subject

      parsed = response.parsed_body
      aggregate_failures do
        expect(parsed['title']).to eq('Unauthorized')
        expect(parsed['detail']).to be_present
      end
    end
  end
end
