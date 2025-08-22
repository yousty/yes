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
      end

      context 'when command execution fails' do
        let(:command_response) do
          Yes::Core::CommandResponse.new(cmd:, event: nil, error:)
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
            another: nil
          )
          # Add column_names method to the mock's class
          allow(mock.class).to receive(:column_names).and_return(['id', 'revision', 'document_ids', 'another'])
          # Add reload method that returns self
          allow(mock).to receive(:reload).and_return(mock)
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
            expect(draft_latest_event.type).to eq('Test::UserDocumentsApproved')
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
            another: nil
          )
          allow(mock.class).to receive(:column_names).and_return(['id', 'revision', 'another'])
          allow(mock).to receive(:reload).and_return(mock)
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
            expect(draft_latest_event.type).to eq('Test::UserSomeCustomEvent')
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
