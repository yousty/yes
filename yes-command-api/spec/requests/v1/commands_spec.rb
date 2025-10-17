# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Yes::Command::Api::V1::CommandsController', type: :request do
  include_context :request_header_variables

  context 'execute' do
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
        subject: 'Activity',
        context: 'Dummy',
        command: 'DoSomethingElse',
        data: { id: SecureRandom.uuid, what: 'something' }
      }
    end

    shared_examples 'open telemetry trackable' do
      let(:in_memory_exporter) { OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new }
      let(:finished_spans) { in_memory_exporter.finished_spans }

      let(:expected_spans_amount) { 2 }

      let(:default_spans_name) do
        [
          'Request Yes::Command::Api::V1::CommandsController',
          'Response Yes::Command::Api::V1::CommandsController'
        ]
      end
      let(:extra_spans_name) { [] }
      let(:expected_spans_name) { default_spans_name + extra_spans_name }

      let(:default_attribute_keys) do
        {
          default_spans_name[0] => %w[auth_token auth_data params],
          default_spans_name[1] => %w[response.status response.body]
        }
      end
      let(:extra_attribute_keys) { {} }
      let(:expected_attribute_keys) { default_attribute_keys.merge(extra_attribute_keys) }

      context 'when OpenTelemetry tracer is not set' do
        before do
          Yousty::Eventsourcing.configure do |config|
            config.otl_tracer = nil
          end
        end
        it 'does not track anything' do
          expect(OpenTelemetry::Trace).to_not receive(:with_span)

          subject
        end

        it 'does not instantiate OtlTracer' do
          expect(OpenTelemetry.tracer_provider).to_not receive(:tracer)

          subject
        end
      end

      context 'when OpenTelemetry tracer is set' do
        before do
          OpenTelemetry::SDK.configure do |c|
            c.add_span_processor(OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(in_memory_exporter))

            c.service_name = 'SpecService'
            c.service_version = ENV.fetch('APP_VERSION', '1.0.0')
          end
          Yousty::Eventsourcing.configure do |config|
            config.otl_tracer = OpenTelemetry.tracer_provider.tracer('SpecTracer')
          end

          subject
        end

        it 'records expected amount of spans' do
          expect(finished_spans.count).to eq(expected_spans_amount)
        end
        it 'records spans with correct name' do
          expect(finished_spans.pluck(:name)).to match_array(expected_spans_name)
        end

        describe 'spans attributes' do
          it 'records spans with correct attributes' do
            aggregate_failures do
              expected_attribute_keys.each do |span_name, keys|
                expect(finished_spans.find { _1.name == span_name }.attributes.keys).to match_array(keys)
              end
            end
          end
        end
      end
    end

    context 'when unauthenticated' do
      let(:commands) { 'whatever' }
      let(:access_token) { nil }

      it_behaves_like 'authentication failure'
      it_behaves_like 'open telemetry trackable'
    end

    context 'when params are not an array' do
      let(:commands) { 'not an array' }
      let(:expected_details) { { 'message' => 'Commands must be an array' } }

      it_behaves_like 'bad request'
      it_behaves_like 'open telemetry trackable' do
        let(:expected_spans_amount) { 3 }
        let(:extra_spans_name) { ['Set Channel'] }
        let(:extra_attribute_keys) { { extra_spans_name[0] => %w[channel track_sql] } }
      end
    end

    context 'when params are incomplete' do
      let(:expected_details) do
        {
          invalid: [{
            command: commands.last,
            error: "Missing keys: #{missing_keys.sort.join(', ')}"
          }],
          message: 'A command must have the following keys: command, data, context, subject'
        }.deep_stringify_keys
      end

      context 'when context is missing' do
        let(:commands) do
          [valid_command, { command: 'DoSomething', subject: 'Activity', data: { id: '123' } }]
        end
        let(:missing_keys) { ['context'] }

        it_behaves_like 'bad request'
        it_behaves_like 'does not run any command'
        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_amount) { 3 }
          let(:extra_spans_name) { ['Set Channel'] }
          let(:extra_attribute_keys) { { extra_spans_name[0] => %w[channel track_sql] } }
        end
      end

      context 'when subject is missing' do
        let(:commands) do
          [
            valid_command,
            { command: 'DoSomething', context: 'Dummy', data: { id: '123' } }
          ]
        end
        let(:missing_keys) { ['subject'] }

        it_behaves_like 'bad request'
        it_behaves_like 'does not run any command'
        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_amount) { 3 }
          let(:extra_spans_name) { ['Set Channel'] }
          let(:extra_attribute_keys) { { extra_spans_name[0] => %w[channel track_sql] } }
        end
      end

      context 'when command is missing' do
        let(:commands) do
          [
            valid_command,
            { subject: 'Activity', context: 'Dummy', data: { id: '123' } }
          ]
        end
        let(:missing_keys) { ['command'] }

        it_behaves_like 'bad request'
        it_behaves_like 'does not run any command'
        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_amount) { 3 }
          let(:extra_spans_name) { ['Set Channel'] }
          let(:extra_attribute_keys) { { extra_spans_name[0] => %w[channel track_sql] } }
        end
      end

      context 'when data is missing' do
        let(:commands) do
          [
            valid_command,
            { subject: 'Activity', context: 'Dummy', command: 'DoSomething' }
          ]
        end
        let(:missing_keys) { ['data'] }

        it_behaves_like 'bad request'
        it_behaves_like 'does not run any command'
        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_amount) { 3 }
          let(:extra_spans_name) { ['Set Channel'] }
          let(:extra_attribute_keys) { { extra_spans_name[0] => %w[channel track_sql] } }
        end
      end

      context 'when multiple params are missing' do
        let(:commands) { [valid_command, { command: 'DoSomething' }] }
        let(:missing_keys) { %w[context subject data] }

        it_behaves_like 'bad request'
        it_behaves_like 'does not run any command'
        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_amount) { 3 }
          let(:extra_spans_name) { ['Set Channel'] }
          let(:extra_attribute_keys) { { extra_spans_name[0] => %w[channel track_sql] } }
        end
      end
    end

    context 'when :channel param and identity id are absent' do
      let(:identity_id) { nil }
      let(:host) { 'www.xyz.ch' }

      it 'renders error' do
        subject
        aggregate_failures do
          expect(response).to have_http_status(:bad_request)
          expect(response.parsed_body).to eq('title' => '"channel" param is required')
        end
      end

      it_behaves_like 'open telemetry trackable' do
        let(:expected_spans_amount) { 3 }
        let(:extra_spans_name) { ['Set Channel'] }
        let(:extra_attribute_keys) { { extra_spans_name[0] => %w[track_sql] } }
      end
    end

    context 'when command is not existing' do
      let(:id) { SecureRandom.uuid }
      let(:commands) do
        [
          valid_command,
          {
            subject: 'Activity',
            context: 'Dummy',
            command: 'DoSomethingNonExisting',
            data: { id: }
          }
        ]
      end

      let(:expected_details) do
        {
          'invalid' => [],
          'not_found' => [commands.last.deep_stringify_keys]
        }
      end

      it_behaves_like 'bad request'
      it_behaves_like 'does not run any command'
      it_behaves_like 'open telemetry trackable' do
        let(:expected_spans_amount) { 4 }
        let(:extra_spans_name) { ['Set Channel', 'Deserialize Commands'] }
        let(:extra_attribute_keys) do
          {
            extra_spans_name[0] => %w[channel track_sql],
            extra_spans_name[1] => %w[failed track_sql]
          }
        end
      end
    end

    context 'when command schema check is failing' do
      let(:commands) do
        [
          valid_command,
          {
            subject: 'Activity',
            context: 'Dummy',
            command: 'DoSomething',
            data: { what: 'abc' }
          }
        ]
      end

      let(:expected_details) do
        {
          'invalid' => [commands.last.deep_stringify_keys],
          'not_found' => []
        }
      end

      it_behaves_like 'bad request'
      it_behaves_like 'does not run any command'
      it_behaves_like 'open telemetry trackable' do
        let(:expected_spans_amount) { 4 }
        let(:extra_spans_name) { ['Set Channel', 'Deserialize Commands'] }
        let(:extra_attribute_keys) do
          {
            extra_spans_name[0] => %w[channel track_sql],
            extra_spans_name[1] => %w[failed track_sql]
          }
        end
      end
    end

    context 'when command is not authorized' do
      let(:commands) do
        [
          valid_command,
          {
            subject: 'Activity',
            context: 'Dummy',
            command: 'DoSomethingMoreImpossible',
            data: { id: SecureRandom.uuid, what: 'something' }
          }
        ]
      end
      let(:error_msg) { 'You cannot do this' }

      it_behaves_like 'authorization failure'
      it_behaves_like 'does not run any command'
      it_behaves_like 'open telemetry trackable' do
        let(:expected_spans_amount) { 5 }
        let(:extra_spans_name) { ['Set Channel', 'Authorize Commands', 'Deserialize Commands'] }
        let(:extra_attribute_keys) do
          {
            extra_spans_name[0] => %w[channel track_sql],
            extra_spans_name[1] => %w[track_sql unauthorized],
            extra_spans_name[2] => %w[track_sql]
          }
        end
      end
    end

    context 'when validation is failing' do
      let(:commands) do
        [
          valid_command,
          {
            subject: 'Activity',
            context: 'Dummy',
            command: 'DoSomethingUncommon',
            data: { id: SecureRandom.uuid, what: 'something' }
          }
        ]
      end
      let(:error_msg) { 'This is not valid' }

      it_behaves_like 'unprocessable entity response'
      it_behaves_like 'does not run any command'
      it_behaves_like 'open telemetry trackable' do
        let(:expected_spans_amount) { 5 }
        let(:extra_spans_name) { ['Set Channel', 'Authorize Commands', 'Deserialize Commands'] }
        let(:extra_attribute_keys) do
          {
            extra_spans_name[0] => %w[channel track_sql],
            extra_spans_name[1] => %w[track_sql],
            extra_spans_name[2] => %w[track_sql]
          }
        end
      end
    end

    context 'when commands are successful' do
      let(:commands) do
        [
          {
            subject: 'Activity',
            context: 'Dummy',
            command: 'DoSomethingElse',
            data: { id: SecureRandom.uuid, what: 'something' }
          },
          {
            subject: 'Activity',
            context: 'Dummy',
            command: 'DoSomethingImpossible',
            data: { id: SecureRandom.uuid, what: 'something' }
          }
        ]
      end

      before do
        # TODO: @nico said we can use anymore CMD registry, we need some real aggregate
        command_registry = Yousty::Eventsourcing::CommandRegistry.new
        command_registry.register(
          Dummy::Commands::Activity::DoSomethingElse,
          Dummy::Commands::Activity::DummyHandler
        )
        command_registry.register(
          Dummy::Commands::Activity::DoSomethingImpossible,
          Dummy::Commands::Activity::DummyHandler
        )
        Yousty::Eventsourcing.configure do |config|
          config.command_registry = command_registry
        end
      end

      shared_examples 'publishes messages' do
        it 'publishes correct messages to proper channel' do
          subject
          messages = MessageBus.backlog channel
          batch_id = response.parsed_body.dig(0, 'batch_id')
          messages_data = messages.map { |message| message.data }

          aggregate_failures do
            expect(messages.size).to eq(4)

            expect(messages_data[0]['type']).to eq('batch_started')
            expect(messages_data[1]['type']).to eq('command_success')
            expect(messages_data[2]['type']).to eq('command_success')
            expect(messages_data[3]['type']).to eq('batch_finished')

            expect(messages_data[0]['batch_id']).to eq(batch_id)
            expect(messages_data[1]['batch_id']).to eq(batch_id)
            expect(messages_data[2]['batch_id']).to eq(batch_id)
            expect(messages_data[3]['batch_id']).to eq(batch_id)

            expect(messages_data[1]['command']).to(
              eq('Dummy::Commands::Activity::DoSomethingElse')
            )
            expect(messages_data[2]['command']).to(
              eq('Dummy::Commands::Activity::DoSomethingImpossible')
            )
          end
        end
      end

      context 'running commands inline' do
        before do
          Yousty::Eventsourcing.configure do |config|
            config.command_notifier_classes = []
            config.process_commands_inline = true
          end
        end

        it_behaves_like 'successful inline write response'
        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_amount) { 9 }
          let(:extra_spans_name) do
            [
              'Set Channel',
              'Authorize Commands',
              'Deserialize Commands',
              'Command Bus Schedule',
              'Process Dummy::Commands::Activity::DoSomethingElse',
              'Process Dummy::Commands::Activity::DoSomethingImpossible',
              'Yousty::Eventsourcing::CommandProcessor'
            ]
          end
          let(:extra_attribute_keys) do
            {
              extra_spans_name[0] => %w[track_sql channel],
              extra_spans_name[1] => %w[track_sql],
              extra_spans_name[2] => %w[track_sql],
              extra_spans_name[3] => %w[track_sql
                                        perform_method
                                        origin
                                        name
                                        correlation_id
                                        caller_id
                                        caller_type
                                        otl_contexts.root.traceparent
                                        otl_contexts.root.service],
              extra_spans_name[4] => %w[command_response],
              extra_spans_name[5] => %w[command_response],
              extra_spans_name[6] => %w[total_commands_in_batch]
            }
          end
        end

        context 'executing commands' do
          let(:handler) { instance_spy(Dummy::Commands::Activity::DummyHandler) }

          before do
            allow(Dummy::Commands::Activity::DummyHandler).to receive(:new).and_return(handler)
            allow(handler).to receive(:call)
          end

          it 'calls command handlers' do
            subject

            expect(handler).to have_received(:call).twice
          end

          context 'adding identity id to command metadata' do
            let(:command_bus) { instance_spy(Yousty::Eventsourcing::CommandBus) }
            before do
              allow(Yousty::Eventsourcing::CommandBus).to receive(:new).and_return(command_bus)
            end

            it 'adds identity id to command metadata' do
              subject
              expect(command_bus).to have_received(:call) do |commands|
                commands.each do |command|
                  expect(command.metadata[:identity_id]).to eq(auth_user_uuid)
                end
              end
            end
          end
        end

        context 'when using message bus command notifier' do
          let(:channel) { auth_user_uuid }
          let(:params) { { commands: } }

          before do
            Yousty::Eventsourcing.configure do |config|
              config.command_notifier_classes = [Yousty::Eventsourcing::CommandNotifiers::MessageBusNotifier]
            end
          end

          it_behaves_like 'successful inline write response'
          it_behaves_like 'publishes messages'

          context 'when using custom channel' do
            let(:channel) { 'custom_notifications/12345' }
            let(:params) { { commands:, channel: } }
            let(:identity_id) { nil }
            let(:host) { 'www.xyz.ch' }

            it_behaves_like 'publishes messages'
          end
        end
      end

      context 'overriding config.process_commands_inline config option' do
        context 'when forcing sync processing' do
          let(:params) { super().merge(async: 'false') }

          before do
            Yousty::Eventsourcing.configure do |config|
              config.process_commands_inline = true
              config.command_notifier_classes = [Yousty::Eventsourcing::CommandNotifiers::MessageBusNotifier]
            end
          end

          it_behaves_like 'successful inline write response'
          it_behaves_like 'publishes messages' do
            let(:channel) { auth_user_uuid }
          end

          context 'when more than 10 commands were submitted' do
            let(:commands) { super() * 6 }

            it 'returns error' do
              subject
              aggregate_failures do
                expect(response.parsed_body).to(
                  eq('error' => 'Too many commands. You can process up to 10 commands inline.')
                )
                expect(response).to have_http_status(:unprocessable_content)
              end
            end
          end
        end

        context 'when forcing async processing' do
          let(:params) { super().merge(async: 'true') }

          before do
            Yousty::Eventsourcing.configure do |config|
              config.process_commands_inline = false
              config.command_notifier_classes = [Yousty::Eventsourcing::CommandNotifiers::MessageBusNotifier]
            end
          end

          it_behaves_like 'successful write response'
        end
      end

      context 'running commands async' do
        before do
          Yousty::Eventsourcing.configure do |config|
            config.command_notifier_classes = []
            config.process_commands_inline = false
          end
        end

        it_behaves_like 'successful write response'
        it_behaves_like 'open telemetry trackable' do
          let(:expected_spans_amount) { 6 }
          let(:extra_spans_name) do
            [
              'Set Channel',
              'Authorize Commands',
              'Deserialize Commands',
              'Command Bus Schedule'
            ]
          end
          let(:extra_attribute_keys) do
            {
              extra_spans_name[0] => %w[track_sql channel],
              extra_spans_name[1] => %w[track_sql],
              extra_spans_name[2] => %w[track_sql],
              extra_spans_name[3] => %w[origin perform_method track_sql]
            }
          end
        end
      end
    end

    context 'when including a command group' do
      let(:commands) do
        [
          {
            subject: 'Activity',
            context: 'Dummy',
            command: 'DoSomethingElse',
            data: { id: SecureRandom.uuid, what: 'something' }
          },
          {
            subject: 'Company',
            context: 'Dummy',
            command: 'DoSomethingCompounded',
            data: {
              company: {
                company_id: SecureRandom.uuid,
                name: 'New Company Name',
                description: 'New Company Description'
              },
              user: {
                user_id: SecureRandom.uuid,
                first_name: 'John',
                last_name: 'Doe'
              }
            }
          }
        ]
      end

      let(:command_registry) { Yousty::Eventsourcing::CommandRegistry.new }

      before do
        Yousty::Eventsourcing.configure do |config|
          config.command_notifier_classes = []
          config.process_commands_inline = true

          config.command_registry = command_registry
        end

        command_registry.register(
          Dummy::Commands::Activity::DoSomethingElse,
          Dummy::Commands::Activity::DummyHandler
        )
        command_registry.register(
          Dummy::Company::Commands::DoSomethingCompounded::Command,
          Dummy::Commands::Activity::DummyHandler
        )
      end

      it_behaves_like 'successful inline write response'

      context 'executing commands' do
        let(:handler) { instance_spy(Dummy::Commands::Activity::DummyHandler) }

        before do
          allow(Dummy::Commands::Activity::DummyHandler).to receive(:new).and_return(handler)
          allow(handler).to receive(:call)
        end

        it 'calls command handlers' do
          subject

          expect(handler).to have_received(:call).twice
        end

        context 'when calling authorizers' do
          before do
            allow(Dummy::User::Commands::ChangeName::Authorizer).to receive(:call)
            allow(Dummy::Company::Commands::ChangeName::Authorizer).to receive(:call)
            allow(Dummy::Company::Commands::ChangeDescription::Authorizer).to receive(:call)
          end

          it 'calls authorizers for each command in the group' do
            subject

            aggregate_failures do
              expect(Dummy::User::Commands::ChangeName::Authorizer).to have_received(:call)
              expect(Dummy::Company::Commands::ChangeName::Authorizer).to have_received(:call)
              expect(Dummy::Company::Commands::ChangeDescription::Authorizer).to have_received(:call)
            end
          end
        end

        context 'when calling validators' do
          before do
            allow(Dummy::User::Commands::ChangeName::Validator).to receive(:call)
            allow(Dummy::Company::Commands::ChangeName::Validator).to receive(:call)
            allow(Dummy::Company::Commands::ChangeDescription::Validator).to receive(:call)
          end

          it 'calls validators for each command in the group' do
            subject

            aggregate_failures do
              expect(Dummy::User::Commands::ChangeName::Validator).to have_received(:call)
              expect(Dummy::Company::Commands::ChangeName::Validator).to have_received(:call)
              expect(Dummy::Company::Commands::ChangeDescription::Validator).to have_received(:call)
            end
          end
        end
      end
    end
  end
end
