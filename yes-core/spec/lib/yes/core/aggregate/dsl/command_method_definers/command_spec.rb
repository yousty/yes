# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::Dsl::CommandMethodDefiners::Command do
  subject { described_class.new(command_data).call }

  let(:command_data) do
    Yes::Core::Aggregate::Dsl::CommandData.new(
      command_name,
      aggregate_class,
      context: 'Test',
      aggregate: 'User',
      payload_attributes: {
        document_ids: :string,
        another: :string
      }
    )
  end

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
        it 'updates the read model with payload and revision' do
          expect(aggregate).to receive(:update_read_model).with({ document_ids:, another:, revision: 0 })

          aggregate.approve_documents(payload)
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
