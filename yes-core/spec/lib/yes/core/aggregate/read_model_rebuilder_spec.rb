# frozen_string_literal: true

RSpec.describe Yes::Core::Aggregate::ReadModelRebuilder do
  let(:aggregate) { Test::User::Aggregate.new }
  let(:rebuilder) { described_class.new(aggregate) }
  let(:read_model) { aggregate.read_model }
  let!(:created_at_old) { read_model.created_at }

  describe '#call' do
    # setup aggregate running some commands
    before do
      aggregate.some_custom_command(another: 'Value 1')
      aggregate.approve_documents(document_ids: '123', another: 'Blarb')
      aggregate.some_custom_command(another: 'Value 2')
      aggregate.some_custom_command(another: 'Value 3')
      aggregate.publish
    end

    context 'when remove is true (default)' do
      subject { rebuilder.call }

      before do
        allow(read_model).to receive(:destroy).and_call_original

        subject
      end

      it 'destroys the existing read model' do
        expect(read_model).to have_received(:destroy)
      end

      it 'processes each event to update the read model' do
        aggregate_failures do
          expect(read_model.reload.created_at).to be > created_at_old
          expect(aggregate.another).to eq('Value 3')
          expect(aggregate.document_ids).to eq('123')
          expect(aggregate.published).to eq(true)
          expect(aggregate.revision).to eq(4)
        end
      end
    end

    context 'when remove is false' do
      subject { rebuilder.call(remove: false) }

      before do
        allow(read_model).to receive(:destroy).and_call_original
        allow(read_model).to receive(:update).and_call_original

        subject
      end

      it 'does not destroy the existing read model' do
        expect(read_model).not_to have_received(:destroy)
      end

      it 'resets the revision to -1' do
        expect(read_model).to have_received(:update).with(aggregate.revision_column => -1)
      end

      it 'processes each event to update the read model' do
        aggregate_failures do
          expect(read_model.reload.created_at).to eq(created_at_old)
          expect(aggregate.another).to eq('Value 3')
          expect(aggregate.document_ids).to eq('123')
          expect(aggregate.published).to eq(true)
          expect(aggregate.revision).to eq(4)
        end
      end
    end
  end
end
