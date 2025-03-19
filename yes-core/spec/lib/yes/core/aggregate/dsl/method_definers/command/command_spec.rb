# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::MethodDefiners::Command::Command do
  subject { described_class.new(command_data).call }

  let(:command_data) do
    Yes::Core::Aggregate::Dsl::CommandData.new(
      command_name,
      aggregate_class,
      context:,
      aggregate: aggregate_name,
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

      # context 'when command execution fails' do
      #   before do
      #     allow(aggregate).to receive(:execute_command).and_return(command_response)
      #   end

      #   it 'does not update the read model' do
      #     expect(aggregate).not_to receive(:update_read_model)

      #     aggregate.approve_documents(payload)
      #   end
      # end

      # it 'returns the command response' do
      #   cmd = Yes::Core::Command.new(
      #     command_id: SecureRandom.uuid,
      #     payload:,
      #     metadata: {}
      #   )

      #   command_response = Yes::Core::CommandResponse.new(
      #     cmd:,
      #     event: Yes::Core::Event.new(
      #       id: SecureRandom.uuid,
      #       type: 'Test::User::DocumentsApproved',
      #       data: payload,
      #       stream_revision: 2
      #     )
      #   )

      #   allow(aggregate).to receive(:execute_command).and_return(command_response)

      #   expect(aggregate.approve_documents(payload)).to eq(command_response)
      # end
    end
  end
end
