# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::MethodDefiners::Command::Command do
  subject { described_class.new(command_data).call }

  let(:command_data) do
    Yes::Core::Aggregate::Dsl::CommandData.new(
      command_name,
      aggregate_class,
      context:,
      aggregate: aggregate_name,
      event_name:,
      payload_attributes:
    )
  end

  let(:context) { 'Test' }
  let(:aggregate_name) { 'User' }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:command_name) { :approve_documents }
  let(:aggregate) { aggregate_class.new }
  let(:event_name) { nil }
  let(:payload_attributes) { { document_ids: :string, another: :string } }

  describe '#call' do
    context 'command class' do
      before do
        # command method is already defined so remove it to test adding it
        aggregate_class.remove_method(command_name) if aggregate_class.method_defined?(command_name)

        subject
      end

      it 'defines the command method' do
        expect(aggregate).to respond_to(command_name)
      end
    end

    context 'when executing the command' do
      let(:command_name) { :approve_documents }
      let(:document_ids) { SecureRandom.uuid }
      let(:another) { 'test_value' }
      let(:payload) { { document_ids:, another: } }

      context 'when command execution succeeds' do
        let(:stream) { PgEventstore::Stream.new(context:, stream_name:, stream_id:) }
        let(:stream_name) { aggregate_name }
        let(:stream_id) { aggregate.id }
        let(:latest_event) { PgEventstore.client.read(stream, options: { max_count: 1, direction: :desc }).first }

        context 'with default event name' do
          before { aggregate.approve_documents(payload) }

          it 'updates the read model with payload and revision' do
            aggregate_failures do
              expect(aggregate.revision).to eq(0)
              expect(aggregate.document_ids).to eq(document_ids)
              expect(aggregate.another).to eq(another)
            end
          end

          it 'publishes the event' do
            aggregate_failures do
              expect(latest_event.type).to eq('Test::UserDocumentsApproved')
              expect(latest_event.data).to eq({ user_id: aggregate.id }.merge(payload).stringify_keys)
            end
          end
        end

        context 'with single payload attribute' do
          let(:payload_attributes) { { another: :string } }
          let(:payload) { another }

          it 'updates the read model with payload and revision' do
            aggregate.some_custom_command(payload)

            aggregate_failures do
              expect(aggregate.revision).to eq(0)
              expect(aggregate.another).to eq(another)
            end
          end

          it 'publishes the event' do
            aggregate.some_custom_command(payload)

            aggregate_failures do
              expect(latest_event.type).to eq('Test::UserSomeCustomEvent')
              expect(latest_event.data).to eq({ user_id: aggregate.id, another: }.stringify_keys)
            end
          end

          context 'when command takes locale param' do
            let(:payload) { 'new description' }
            let(:payload_attributes) { { locale_test: :string, locale: :locale } }

            it 'publishes the event with correct locale' do
              aggregate.test_command_with_locale(payload)

              aggregate_failures do
                expect(latest_event.type).to eq('Test::UserLocaleTestChanged')
                expect(latest_event.data).
                  to eq({ user_id: aggregate.id, locale_test: payload, locale: 'de-CH' }.stringify_keys)
              end
            end
          end

          context 'when command takes param with default value' do
            let(:payload_attributes) { { default_payload_test: { type: :string, default: 'foo' } } }

            it 'publishes the event with correct value' do
              aggregate.test_command_with_default_payload

              aggregate_failures do
                expect(latest_event.type).to eq('Test::UserDefaultPayloadTestChanged')
                expect(latest_event.data).
                  to eq({ user_id: aggregate.id, default_payload_test: 'foo' }.stringify_keys)
              end
            end
          end
        end

        shared_examples 'a command that updates the single attribute: another' do
          before { aggregate.some_custom_command(payload) }

          it 'updates the read model with payload and revision' do
            aggregate_failures do
              expect(aggregate.revision).to eq(0)
              expect(aggregate.another).to eq(another)
            end
          end

          it 'publishes the event' do
            aggregate_failures do
              expect(latest_event.type).to eq('Test::UserSomeCustomEvent')
              expect(latest_event.data).to eq({ user_id: aggregate.id, another: }.stringify_keys)
            end
          end
        end

        context 'when using hash payload' do
          let(:payload) { { another: 'test_value' } }
          let(:payload_attributes) { { another: :string } }

          it_behaves_like 'a command that updates the single attribute: another'

          context 'when command takes locale param' do
            let(:payload) { { locale_test: 'new description' } }
            let(:payload_attributes) { { locale_test: :string, locale: :locale } }

            it 'publishes the event with correct locale' do
              aggregate.test_command_with_locale(payload)

              aggregate_failures do
                expect(latest_event.type).to eq('Test::UserLocaleTestChanged')
                expect(latest_event.data).
                  to eq({ user_id: aggregate.id, locale_test: payload[:locale_test], locale: 'de-CH' }.stringify_keys)
              end
            end
          end
        end

        context 'when using shorthand value payload' do
          let(:payload) { another }

          context 'when using a single payload attribute' do
            let(:payload_attributes) { { another: :string } }

            it_behaves_like 'a command that updates the single attribute: another'
          end

          context 'when command implements multiple payload attributes' do
            let(:payload_attributes) { { another: :string, document_ids: :string } }

            it 'raises an error' do
              expect { aggregate.approve_documents(payload) }.
                to raise_error('Payload attributes must be a Hash with a single key (not including locale key)')
            end
          end
        end

        context 'with custom event name' do
          let(:command_name) { :approve_documents_with_custom_event }

          before { aggregate.approve_documents_with_custom_event }

          it 'publishes the event with the custom name' do
            expect(latest_event.type).to eq('Test::UserDocumentHappilyApproved')
          end
        end

        context 'when skipping guards' do
          let(:command_name) { :test_command_with_guard }
          let(:payload_attributes) { { another: :string } }
          let(:payload) { { another: 'test_value' } }

          before do
            # Remove the command method if it exists from a previous test
            Test::User::Aggregate.remove_method(:test_command_with_guard) if Test::User::Aggregate.method_defined?(:test_command_with_guard)

            # Define a command with a guard that should fail
            Test::User::Aggregate.command :test_command_with_guard do
              payload another: :string
              event :test_command_with_guard_executed

              guard :should_fail do
                false # This guard always fails
              end
            end
          end

          after do
            # Clean up the test command
            Test::User::Aggregate.singleton_class.instance_variable_set(
              :@commands,
              Test::User::Aggregate.commands.except(:test_command_with_guard)
            )
          end

          context 'with guards enabled (default)' do
            it 'evaluates guards and returns error when guard fails' do
              response = aggregate.test_command_with_guard(payload)

              expect(response.success?).to be false
              expect(response.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)
              expect(response.error.message).to include("Guard 'should_fail' failed")
            end

            it 'evaluates guards when guards: true is explicitly passed' do
              response = aggregate.test_command_with_guard(payload, guards: true)

              expect(response.success?).to be false
              expect(response.error).to be_a(Yes::Core::CommandHandling::GuardEvaluator::InvalidTransition)
              expect(response.error.message).to include("Guard 'should_fail' failed")
            end
          end

          context 'with guards disabled' do
            it 'skips guard evaluation when guards: false is passed' do
              expect { aggregate.test_command_with_guard(payload, guards: false) }.
                not_to raise_error
            end

            it 'publishes the event even when guard would fail' do
              aggregate.test_command_with_guard(payload, guards: false)

              stream = PgEventstore::Stream.new(
                context:,
                stream_name: aggregate_name,
                stream_id: aggregate.id
              )
              latest_event = PgEventstore.client.read(stream, options: { max_count: 1, direction: :desc }).first

              expect(latest_event.type).to eq('Test::UserTestCommandWithGuardExecuted')
            end

            it 'updates the read model when guards are skipped' do
              aggregate.test_command_with_guard(payload, guards: false)

              expect(aggregate.another).to eq('test_value')
            end
          end
        end

        context 'when testing option separation from payload' do
          it 'correctly separates guards option from payload when using explicit hash' do
            # Test that the guards option is properly separated from payload
            # When using guards option, payload must be passed as explicit first argument

            # Pass payload as explicit hash, guards as option
            response = aggregate.approve_documents({ document_ids: 'doc-123', another: 'test' }, guards: false)

            # Should succeed because we skipped guard evaluation
            expect(response.success?).to be true

            # Verify the event contains only the payload data, not the guards option
            stream = PgEventstore::Stream.new(
              context:,
              stream_name: aggregate_name,
              stream_id: aggregate.id
            )
            latest_event = PgEventstore.client.read(stream, options: { max_count: 1, direction: :desc }).first

            # The event should contain only payload data, guards option should not be in the event
            expect(latest_event.data).to include(
              'document_ids' => 'doc-123',
              'another' => 'test'
            )
            expect(latest_event.data).not_to have_key('guards')
          end

          it 'handles different calling patterns correctly' do
            # Test various ways of passing payload with and without options

            # Method 1: Hash payload as first arg, option as kwarg
            response1 = aggregate.approve_documents({ document_ids: 'doc-1', another: 'test1' }, guards: false)
            expect(response1.success?).to be true

            # Method 2: Kwargs only (no options) - all kwargs become payload
            response2 = aggregate.approve_documents(document_ids: 'doc-2', another: 'test2')
            expect(response2.success?).to be true

            # Method 3: Hash payload without options
            response3 = aggregate.approve_documents({ document_ids: 'doc-3', another: 'test3' })
            expect(response3.success?).to be true

            # Verify all three created events with correct payload
            stream = PgEventstore::Stream.new(
              context:,
              stream_name: aggregate_name,
              stream_id: aggregate.id
            )
            events = PgEventstore.client.read(stream).to_a

            expect(events[-3].data).to include('document_ids' => 'doc-1', 'another' => 'test1')
            expect(events[-2].data).to include('document_ids' => 'doc-2', 'another' => 'test2')
            expect(events[-1].data).to include('document_ids' => 'doc-3', 'another' => 'test3')

            # None should have guards in the data
            events.last(3).each do |event|
              expect(event.data).not_to have_key('guards')
            end
          end

          it 'requires explicit hash when using guards option to avoid ambiguity' do
            # To use guards as an option, you must pass payload as explicit first argument
            # This avoids ambiguity about whether "guards" is payload or option

            # This passes guards: false as an option (skips guard evaluation)
            response_with_option = aggregate.approve_documents({ document_ids: 'doc-4', another: 'test4' }, guards: false)
            expect(response_with_option.success?).to be true

            # This passes all kwargs as payload (guards would be payload if included)
            response_without_option = aggregate.approve_documents(document_ids: 'doc-5', another: 'test5')
            expect(response_without_option.success?).to be true

            stream = PgEventstore::Stream.new(
              context:,
              stream_name: aggregate_name,
              stream_id: aggregate.id
            )
            events = PgEventstore.client.read(stream).to_a

            # Both events should only have the expected payload attributes
            expect(events[-2].data).to include('document_ids' => 'doc-4', 'another' => 'test4')
            expect(events[-2].data).not_to have_key('guards')

            expect(events[-1].data).to include('document_ids' => 'doc-5', 'another' => 'test5')
            expect(events[-1].data).not_to have_key('guards')
          end
        end

        context 'with custom state update' do
          before do
            Test::User::Aggregate.command :do_something do
              payload blah_blah: :integer, huhu: :string

              event :something_done

              update_state do
                name { "#{payload[:blah_blah]} #{payload[:huhu]}" }
                email { "#{payload[:huhu]}@xyz.ch" }
              end
            end
            aggregate.do_something(payload)
          end

          let(:payload) { { blah_blah: 123, huhu: 'test_value' } }

          it 'updates the state' do
            expect(aggregate.name).to eq('123 test_value')
            expect(aggregate.email).to eq('test_value@xyz.ch')
          end
        end

        context 'when passing metadata option' do
          let(:stream) { PgEventstore::Stream.new(context:, stream_name: aggregate_name, stream_id: aggregate.id) }
          let(:latest_event) { PgEventstore.client.read(stream, options: { max_count: 1, direction: :desc }).first }

          it 'correctly separates metadata option from payload and includes it in the payload' do
            # Pass payload as explicit hash with metadata option
            response = aggregate.approve_documents(
              { document_ids: 'doc-123', another: 'test' },
              metadata: { 'custom_key' => 'custom_value' }
            )

            expect(response.success?).to be true

            # Verify the event data includes the payload fields
            expect(latest_event.data).to include(
              'document_ids' => 'doc-123',
              'another' => 'test'
            )
            # Verify the metadata is in the event metadata field
            expect(latest_event.metadata).to include(
              'custom_key' => 'custom_value'
            )
          end

          it 'handles metadata option with kwargs payload' do
            # Pass kwargs as payload with metadata option
            response = aggregate.approve_documents(
              document_ids: 'doc-456',
              another: 'test2',
              metadata: { 'key' => 'value' }
            )

            expect(response.success?).to be true

            # Verify the event data includes the payload fields
            expect(latest_event.data).to include(
              'document_ids' => 'doc-456',
              'another' => 'test2'
            )
            # Verify the metadata is in the event metadata field
            expect(latest_event.metadata).to include(
              'key' => 'value'
            )
          end

          it 'works with both guards and metadata options' do
            # Pass payload with both guards and metadata options
            response = aggregate.approve_documents(
              { document_ids: 'doc-789', another: 'test3' },
              guards: false,
              metadata: { 'source' => 'api' }
            )

            expect(response.success?).to be true

            # Verify the event data includes the payload fields
            expect(latest_event.data).to include(
              'document_ids' => 'doc-789',
              'another' => 'test3'
            )
            # Verify guards is not in the payload data
            expect(latest_event.data).not_to have_key('guards')
            # Verify the metadata is in the event metadata field
            expect(latest_event.metadata).to include(
              'source' => 'api'
            )
          end

          it 'does not add metadata to payload when metadata option is not provided' do
            response = aggregate.approve_documents(
              { document_ids: 'doc-999', another: 'test4' }
            )

            expect(response.success?).to be true

            # Verify the event payload does not include metadata key
            expect(latest_event.data).to include(
              'document_ids' => 'doc-999',
              'another' => 'test4'
            )
            expect(latest_event.data).not_to have_key('metadata')
          end
        end
      end

      context 'when command execution fails' do
        let(:command_response) do
          Yes::Core::Commands::Response.new(cmd:, event: nil, error:)
        end

        let(:cmd) do
          Test::User::Commands::ApproveDocuments::Command.new(payload.merge(user_id: aggregate.id))
        end

        let(:error) { Yes::Core::CommandHandling::GuardEvaluator::TransitionError.new }

        before { allow(aggregate).to receive(:execute_command).and_return(command_response) }

        it 'does not update the read model' do
          aggregate_failures do
            expect(aggregate.revision).to eq(-1)
            expect(aggregate.document_ids).to eq(nil)
            expect(aggregate.another).to eq(nil)
          end
        end
      end

      context 'when aggregate is in draft mode' do
        let(:draft_aggregate) { aggregate_class.new(aggregate.id, draft: true) }
        let(:draft_stream) { PgEventstore::Stream.new(context:, stream_name: "#{aggregate_name}Draft", stream_id: draft_aggregate.id) }
        let(:draft_latest_event) { PgEventstore.client.read(draft_stream, options: { max_count: 1, direction: :desc }).first }
        let(:changes_read_model) do
          mock = instance_double('TestUserChange',
                                 update!: true,
                                 id: draft_aggregate.id,
                                 revision: -1,
                                 document_ids: nil,
                                 another: nil,
                                 pending_update_since: nil,
                                 pending_update_since?: false)
          # Add column_names method to the mock's class
          allow(mock.class).to receive(:column_names).and_return(%w[id revision document_ids another pending_update_since])
          # Add reload method that returns self
          allow(mock).to receive(:reload).and_return(mock)
          # Add update_column method for pending state management
          allow(mock).to receive(:update_column).with(:pending_update_since, anything)
          mock
        end

        before do
          # Make the aggregate draftable for this test
          aggregate_class.class_eval { draftable }

          # Mock the read_model method to return our mock directly
          allow(draft_aggregate).to receive(:read_model).and_return(changes_read_model)
          allow(draft_aggregate).to receive(:update_draft_aggregate)
          allow(draft_aggregate).to receive(:reload).and_return(draft_aggregate)
          # For a new draft aggregate, revision should be -1 (no stream)
          allow(draft_aggregate).to receive(:revision).and_return(-1)
          # Mock revision_column to avoid accessing column_names
          allow(draft_aggregate).to receive(:revision_column).and_return('revision')
        end

        after do
          # Clean up draftable configuration
          aggregate_class.instance_variable_set(:@is_draftable, false)
          aggregate_class.instance_variable_set(:@draft_context, nil)
          aggregate_class.instance_variable_set(:@draft_aggregate, nil)
        end

        it 'adds draft metadata to the payload' do
          draft_aggregate.approve_documents(payload)

          aggregate_failures do
            expect(draft_latest_event.metadata).to include('draft' => true)
            expect(draft_latest_event.type).to eq('Test::UserDraftDocumentsApproved')
          end
        end

        context 'with existing metadata in payload' do
          let(:payload_with_metadata) do
            payload.merge(metadata: { 'existing_key' => 'existing_value' })
          end

          it 'preserves existing metadata and adds draft flag' do
            draft_aggregate.approve_documents(payload_with_metadata)

            aggregate_failures do
              expect(draft_latest_event.metadata).to include(
                'draft' => true,
                'existing_key' => 'existing_value'
              )
            end
          end
        end

        it 'publishes event to draft stream' do
          draft_aggregate.approve_documents(payload)

          # Verify the event was published to the draft stream
          draft_stream_events = PgEventstore.client.read(draft_stream)
          expect(draft_stream_events.to_a).not_to be_empty

          # Verify no event was published to the non-draft stream
          non_draft_stream = PgEventstore::Stream.new(context:, stream_name: aggregate_name, stream_id: draft_aggregate.id)
          expect { PgEventstore.client.read(non_draft_stream).to_a }.to raise_error(PgEventstore::StreamNotFoundError)
        end
      end

      context 'when aggregate is not in draft mode' do
        it 'does not add draft metadata to the payload' do
          aggregate.approve_documents(payload)

          non_draft_stream = PgEventstore::Stream.new(context:, stream_name: aggregate_name, stream_id: aggregate.id)
          non_draft_latest_event = PgEventstore.client.read(non_draft_stream, options: { max_count: 1, direction: :desc }).first

          expect(non_draft_latest_event.metadata).not_to include('draft')
        end
      end

      context 'when aggregate is in draft mode with shorthand payload' do
        let(:draft_aggregate) { aggregate_class.new(aggregate.id, draft: true) }
        let(:draft_stream) { PgEventstore::Stream.new(context:, stream_name: "#{aggregate_name}Draft", stream_id: draft_aggregate.id) }
        let(:draft_latest_event) { PgEventstore.client.read(draft_stream, options: { max_count: 1, direction: :desc }).first }
        let(:payload_attributes) { { another: :string } }
        let(:payload) { 'test_shorthand_value' }
        let(:changes_read_model) do
          mock = instance_double('TestUserChange',
                                 update!: true,
                                 id: draft_aggregate.id,
                                 revision: -1,
                                 another: nil,
                                 pending_update_since: nil,
                                 pending_update_since?: false)
          allow(mock.class).to receive(:column_names).and_return(%w[id revision another pending_update_since])
          allow(mock).to receive(:reload).and_return(mock)
          allow(mock).to receive(:update_column).with(:pending_update_since, anything)
          mock
        end

        before do
          # Make the aggregate draftable for this test
          aggregate_class.class_eval { draftable }

          # Mock the read_model method to return our mock directly
          allow(draft_aggregate).to receive(:read_model).and_return(changes_read_model)
          allow(draft_aggregate).to receive(:update_draft_aggregate)
          allow(draft_aggregate).to receive(:reload).and_return(draft_aggregate)
          allow(draft_aggregate).to receive(:revision).and_return(-1)
          allow(draft_aggregate).to receive(:revision_column).and_return('revision')
        end

        after do
          # Clean up draftable configuration
          aggregate_class.instance_variable_set(:@is_draftable, false)
          aggregate_class.instance_variable_set(:@draft_context, nil)
          aggregate_class.instance_variable_set(:@draft_aggregate, nil)
        end

        it 'handles shorthand string payload correctly and adds draft metadata' do
          draft_aggregate.some_custom_command(payload)

          aggregate_failures do
            expect(draft_latest_event.metadata).to include('draft' => true)
            expect(draft_latest_event.type).to eq('Test::UserDraftSomeCustomEvent')
            expect(draft_latest_event.data).to include('another' => payload)
          end
        end

        it 'publishes event to draft stream with shorthand payload' do
          draft_aggregate.some_custom_command(payload)

          # Verify the event was published to the draft stream
          draft_stream_events = PgEventstore.client.read(draft_stream)
          expect(draft_stream_events.to_a).not_to be_empty

          # Verify no event was published to the non-draft stream
          non_draft_stream = PgEventstore::Stream.new(context:, stream_name: aggregate_name, stream_id: draft_aggregate.id)
          expect { PgEventstore.client.read(non_draft_stream).to_a }.to raise_error(PgEventstore::StreamNotFoundError)
        end
      end
    end
  end
end
