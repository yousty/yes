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
      payload_attributes: {
        document_ids: :string,
        another: :string
      }
    )
  end

  let(:context) { 'Test' }
  let(:aggregate_name) { 'User' }
  let(:aggregate_class) { Test::User::Aggregate }
  let(:command_name) { :approve_documents }

  let(:aggregate) { aggregate_class.new }
  let(:event_name) { nil }

  describe '#call' do
    before do
      aggregate_class.remove_method(command_name) if aggregate_class.method_defined?(command_name)

      subject
    end

    context 'command class' do
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

        context 'with custom event name' do
          let(:event_name) { :document_happily_approved }

          let(:command_data) do
            Yes::Core::Aggregate::Dsl::CommandData.new(
              :approve_documents_with_custom_event,
              aggregate_class,
              context:,
              aggregate: aggregate_name,
              event_name:
            )
          end

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
    end
  end
end
