# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Yes::Command::Api::V1::CommandsController', type: :request do
  include_context :request_header_variables

  describe 'POST /v1/commands' do
    subject do
      post('/v1/commands', params:, headers: request_headers, as: :json)
    end

    let(:params) { { commands: } }
    let(:commands) { [] }
    let(:auth_user_uuid) { SecureRandom.uuid }
    let(:identity_id) { auth_user_uuid }
    let(:host) { 'www.xyz.ch' }
    let(:access_token) { jwt_sign_in(host:, identity_id:) }

    let(:valid_command) do
      {
        subject: 'User',
        context: 'UserManagement',
        command: 'CreateUser',
        data: { name: 'John Doe', email: 'john@example.com' }
      }
    end

    let(:command_bus) { instance_double(Yes::Core::CommandBus) }
    let(:command_response) { [{ 'id' => SecureRandom.uuid, 'status' => 'success' }] }
    let(:job_response) { double(job_id: 'batch-123') }

    # Default mocks for all specs
    before do
      # Mock eventsourcing config
      allow(Yousty::Eventsourcing).to receive(:config).and_return(
        double(process_commands_inline: false)
      )

      # Mock command bus - flexible setup
      allow(Yes::Core::CommandBus).to receive(:new).and_return(command_bus)
      # The command bus is called with keyword arguments
      allow(command_bus).to receive(:call).with(
        anything, # commands array
        notifier_options: anything
      ).and_return(job_response)

      # Mock validation steps - they should pass by default
      allow(Yousty::Eventsourcing::CommandParamsValidator).to receive(:call)
      allow(Yousty::Eventsourcing::CommandsDeserializer).to receive(:call) do |cmds|
        cmds.map do |cmd|
          TestCommands::UserManagement::CreateUser.new(
            name: cmd[:data][:name],
            email: cmd[:data][:email]
          )
        end
      end
      allow(Yousty::Eventsourcing::CommandsAuthorizer).to receive(:call)
      allow(Yousty::Eventsourcing::CommandsValidator).to receive(:call)
    end

    context 'when unauthenticated' do
      let(:access_token) { nil }

      before { subject }

      it 'returns 401' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when params are not an array' do
      let(:commands) { 'not an array' }

      it 'returns 400' do
        expect(Yousty::Eventsourcing::CommandParamsValidator).
          to receive(:call).
          and_raise(Yousty::Eventsourcing::CommandParamsValidator::CommandParamsInvalid.new('Commands must be an array'))

        subject
        aggregate_failures do
          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body).to include('detail' => { 'message' => 'Commands must be an array' })
        end
      end
    end

    context 'when channel param and identity id are absent' do
      let(:identity_id) { nil }

      before { subject }

      it 'returns 400 with channel required message' do
        aggregate_failures do
          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body).to eq('title' => '"channel" param is required')
        end
      end
    end

    context 'when commands are deserialized' do
      let(:commands) { [valid_command] }
      let(:deserialized_command) do
        TestCommands::UserManagement::CreateUser.new(
          name: valid_command[:data][:name],
          email: valid_command[:data][:email]
        )
      end

      before do
        allow(Yousty::Eventsourcing::CommandsDeserializer).
          to receive(:call).
          and_return([deserialized_command])
      end

      it 'calls CommandsDeserializer with command params' do
        subject

        expect(Yousty::Eventsourcing::CommandsDeserializer).
          to have_received(:call).
          with(commands)
      end

      it 'adds identity_id to command metadata' do
        expect(TestCommands::UserManagement::CreateUser).to receive(:new) do |params|
          expect(params[:metadata]).to include(identity_id: auth_user_uuid)
          deserialized_command
        end

        subject
      end
    end

    context 'when command authorization fails' do
      let(:commands) { [valid_command] }

      before do
        allow(Yousty::Eventsourcing::CommandsAuthorizer).
          to receive(:call).
          and_raise(Yousty::Eventsourcing::CommandsAuthorizer::CommandsNotAuthorized.new(
                      extra: [{ command: valid_command, error: 'Not authorized' }]
                    ))

        subject
      end

      it 'returns 401' do
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when command validation fails' do
      let(:commands) { [valid_command] }

      before do
        allow(Yousty::Eventsourcing::CommandsValidator).
          to receive(:call).
          and_raise(Yousty::Eventsourcing::CommandsValidator::CommandsInvalid.new(
                      extra: [{ command: valid_command, error: 'Invalid data' }]
                    ))

        subject
      end

      it 'returns 422' do
        expect(response).to have_http_status(422)
      end
    end

    context 'when processing commands inline' do
      let(:commands) { [valid_command] }

      before do
        allow(Yousty::Eventsourcing).to receive(:config).and_return(
          double(process_commands_inline: true)
        )
        # Override the default mock to return command_response for inline processing
        allow(command_bus).to receive(:call).with(
          anything,
          notifier_options: anything
        ).and_return(command_response)

        subject
      end

      it 'initializes CommandBus with perform_inline: true' do
        expect(Yes::Core::CommandBus).
          to have_received(:new).
          with(perform_inline: true)
      end

      it 'returns command responses' do
        aggregate_failures do
          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq(command_response)
          expect(command_bus).to have_received(:call).with(
            anything,
            notifier_options: anything
          )
        end
      end

      context 'when forcing async processing' do
        let(:params) { { commands:, async: 'true' } }

        before do
          # Clear any previous test double tracking
          RSpec::Mocks.space.proxy_for(Yes::Core::CommandBus).reset

          # Reset mocks for async behavior
          allow(Yousty::Eventsourcing).to receive(:config).and_return(
            double(process_commands_inline: true)
          )
          allow(Yes::Core::CommandBus).to receive(:new).and_return(command_bus)
          allow(command_bus).to receive(:call).with(
            anything,
            notifier_options: anything
          ).and_return(job_response)

          # Make the request with async param
          post('/v1/commands', params:, headers: request_headers, as: :json)
        end

        it 'initializes CommandBus without perform_inline' do
          expect(Yes::Core::CommandBus).
            to have_received(:new).
            with(no_args)
        end

        it 'returns batch_id' do
          aggregate_failures do
            expect(response).to have_http_status(:ok)
            expect(response.parsed_body).to eq({ 'batch_id' => 'batch-123' })
          end
        end
      end

      context 'with more than 10 commands' do
        let(:commands) { Array.new(11) { valid_command } }

        it 'returns 422 with too many commands error' do
          aggregate_failures do
            expect(response).to have_http_status(:unprocessable_content)
            expect(response.parsed_body).to eq({
                                                 'error' => 'Too many commands. You can process up to 10 commands inline.'
                                               })
          end
        end
      end
    end

    context 'when processing commands async' do
      let(:commands) { [valid_command] }

      before do
        allow(Yousty::Eventsourcing).to receive(:config).and_return(
          double(process_commands_inline: false)
        )
        allow(command_bus).to receive(:call).with(
          anything,
          notifier_options: anything
        ).and_return(job_response)

        subject
      end

      it 'initializes CommandBus without perform_inline' do
        expect(Yes::Core::CommandBus).
          to have_received(:new).
          with(no_args)
      end

      it 'returns batch_id' do
        aggregate_failures do
          expect(response).to have_http_status(:ok)
          expect(response.parsed_body).to eq({ 'batch_id' => 'batch-123' })
        end
      end

      context 'with notifier options' do
        let(:params) { { commands:, channel: 'custom-channel' } }

        it 'passes channel in notifier_options' do
          expect(command_bus).to have_received(:call) do |_cmds, options|
            expect(options[:notifier_options]).to eq({ channel: 'custom-channel' })
          end
        end
      end
    end

    context 'when handling CommandGroup' do
      let(:command_group) { instance_double(Yousty::Eventsourcing::CommandGroup) }
      let(:expanded_commands) do
        [
          TestCommands::UserManagement::CreateUser.new(name: 'John', email: 'john@example.com'),
          TestCommands::UserManagement::CreateUser.new(name: 'Jane', email: 'jane@example.com')
        ]
      end
      let(:commands) { [valid_command] }

      before do
        allow(Yousty::Eventsourcing::CommandsDeserializer).
          to receive(:call).
          and_return([command_group])

        allow(command_group).to receive(:is_a?).
          with(Yousty::Eventsourcing::CommandGroup).
          and_return(true)

        allow(command_group).to receive(:commands).and_return(expanded_commands)
        allow(command_group).to receive(:to_h).and_return({})
        allow(command_group).to receive(:metadata).and_return({})
        allow(command_group).to receive(:class).and_return(double(new: command_group))

        subject
      end

      it 'expands command group into individual commands for validation' do
        aggregate_failures do
          expect(Yousty::Eventsourcing::CommandsAuthorizer).
            to have_received(:call).
            with(expanded_commands, anything)

          expect(Yousty::Eventsourcing::CommandsValidator).
            to have_received(:call).
            with(expanded_commands)
        end
      end

      it 'passes original command group to command bus' do
        expect(command_bus).to have_received(:call) do |cmds, _options|
          expect(cmds).to include(command_group)
        end
      end
    end
  end
end
