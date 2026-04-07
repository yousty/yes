# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Yes::Command::Api::Commands::BatchAuthorizer do
  describe '.call' do
    subject { described_class.call(commands, auth_data) }

    let(:auth_data) { {} }

    context 'when a command has no authorizer defined' do
      let(:commands) do
        [
          Dummy::Activity::Commands::DoSomething::Command.new(what: 'something', id: SecureRandom.uuid)
        ]
      end

      it 'raises CommandsNotAuthorized error' do
        expect { subject }.to(
          raise_error(Yes::Command::Api::Commands::BatchAuthorizer::CommandsNotAuthorized)
        )
      end
    end

    context 'when all commands are authorized' do
      let(:commands) do
        [
          Dummy::Activity::Commands::DoSomethingElse::Command.new(
            what: 'something', id: SecureRandom.uuid
          ),
          Dummy::Activity::Commands::DoSomethingAuthorized::Command.new(
            what: 'something else', id: SecureRandom.uuid
          ),
          Dummy::Actions::Commands::DoSomething::Command.new(
            what: 'something else v2', id: SecureRandom.uuid
          )
        ]
      end

      it 'does not raise any error' do
        expect { subject }.not_to raise_error
      end
    end

    context 'when some commands are not authorized' do
      let(:unauthorized_command_id) { SecureRandom.uuid }
      let(:unauthorized_command_metadata) { { 'meta' => 'data' } }
      let(:unauthorized_command_payload) { { id: SecureRandom.uuid, what: 'something unauthorized' } }
      let(:unauthorized_command_attributes) do
        unauthorized_command_payload.merge(
          { metadata: unauthorized_command_metadata, command_id: unauthorized_command_id }
        )
      end

      let(:commands) do
        [
          Dummy::Activity::Commands::DoSomethingAuthorized::Command.new(
            what: 'something', id: SecureRandom.uuid
          ),
          Dummy::Activity::Commands::DoSomethingAuthorized::Command.new(
            what: 'something else', id: SecureRandom.uuid
          ),
          Dummy::Activity::Commands::DoSomethingUnauthorized::Command.new(
            unauthorized_command_attributes
          )
        ]
      end

      it 'raises proper CommandsNotAuthorized error' do
        expect { subject }.to raise_error do |error|
          aggregate_failures do
            expect(error).to be_a(Yes::Command::Api::Commands::BatchAuthorizer::CommandsNotAuthorized)
            expect(error.extra).to match_array(
              [
                {
                  message: "Don't do this",
                  command: 'Dummy::Activity::Commands::DoSomethingUnauthorized::Command',
                  command_id: unauthorized_command_id,
                  data: unauthorized_command_payload,
                  metadata: unauthorized_command_metadata
                }
              ]
            )
          end
        end
      end
    end

    context 'when some v2 commands not authorized' do
      let(:unauthorized_command_id) { SecureRandom.uuid }
      let(:unauthorized_command_metadata) { { 'meta' => 'data' } }
      let(:unauthorized_command_payload) { { id: SecureRandom.uuid, what: 'something unauthorized v2' } }
      let(:unauthorized_command_attributes) do
        unauthorized_command_payload.merge(
          { metadata: unauthorized_command_metadata, command_id: unauthorized_command_id }
        )
      end

      let(:commands) do
        [
          Dummy::Activity::Commands::DoSomethingAuthorized::Command.new(
            what: 'something', id: SecureRandom.uuid
          ),
          Dummy::Activity::Commands::DoSomethingElse::Command.new(
            what: 'something else', id: SecureRandom.uuid
          ),
          Dummy::Actions::Commands::DoSomething::Command.new(
            what: 'something else v2', id: SecureRandom.uuid
          ),
          Dummy::Actions::Commands::DoSomethingUnauthorized::Command.new(
            unauthorized_command_attributes
          )
        ]
      end

      it 'raises proper CommandsNotAuthorized error' do
        expect { subject }.to raise_error do |error|
          aggregate_failures do
            expect(error).to be_a(Yes::Command::Api::Commands::BatchAuthorizer::CommandsNotAuthorized)
            expect(error.extra).to match_array(
              [
                {
                  message: "V2 Don't do this",
                  command: 'Dummy::Actions::Commands::DoSomethingUnauthorized::Command',
                  command_id: unauthorized_command_id,
                  data: unauthorized_command_payload,
                  metadata: unauthorized_command_metadata
                }
              ]
            )
          end
        end
      end
    end

    context 'when a v2 command has no authorizer defined' do
      let(:commands) do
        [
          Dummy::Actions::Commands::DoSomethingElse::Command.new(
            what: 'something else v2', id: SecureRandom.uuid
          )
        ]
      end

      it 'raises CommandsNotAuthorized error' do
        expect { subject }.to(
          raise_error(Yes::Command::Api::Commands::BatchAuthorizer::CommandsNotAuthorized)
        )
      end
    end
  end
end
