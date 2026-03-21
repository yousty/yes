# frozen_string_literal: true

RSpec.describe Yes::Core::ReadModel::EventHandler do
  subject { described_class.new(read_model, payload_store_lookup: payload_store_lookup) }
  let(:payload_store_lookup) { Yes::Core::PayloadStore::Lookup.new }

  let(:read_model) { double('ReadModel') }

  let(:event_data) { {} }
  let(:metadata) { {} }
  let(:event_type) { 'SomeEvent' }
  let(:event) do
    double('SomeEvent', data: event_data, type: event_type, metadata: metadata, created_at: nil)
  end

  let(:payload_store_client) { double('Payload Store Client') }

  let(:service_response_data) { {} }
  let(:success_response) do
    double(
      'Success Response',
      success?: true,
      failure?: false,
      value!: service_response_data
    )
  end

  let(:failure_response) do
    double('Failure Response', success?: false, failure?: true, failure: 'failure')
  end

  describe '#initialize' do
    it 'stores a read model instance' do
      expect(subject.send(:read_model)).to eq(read_model)
    end

    context 'when read model missing' do
      let(:read_model) { nil }

      it 'raises the ArgumentError' do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#call' do
    before do
      allow(event).to receive(:ps_fields_with_values)
      allow(payload_store_lookup).to(
        receive(:payload_store_client).and_return(payload_store_client)
      )
    end

    context 'when plain event' do
      let(:event_data) { { 'attribute' => 'some plain vaslue' } }

      it 'does not modify event' do
        ev = subject.send(:call, event)

        expect(ev.data).to eq(event_data)
      end
      it 'does not call payload store service' do
        expect(payload_store_client).to_not receive(:call)

        subject
      end
    end

    context 'when the event has large payload store fields' do
      let(:event_data) do
        {
          'description' => 'payload-store:e1759f32',
          'last_name' => 'name',
          'bio' => 'payload-store:f24d29d0'
        }
      end
      let(:ps_fields_with_values) do
        {
          description: 'payload-store:e1759f32',
          bio: 'payload-store:f24d29d0'
        }
      end
      let(:service_response_data) do
        [
          double(
            'PS Response Entry',
            attributes: { value: 'Real Long Text', key: 'payload-store:e1759f32' }
          ),
          double(
            'PS Response Entry',
            attributes: { value: 'Real Long Text', key: 'payload-store:f24d29d0' }
          )
        ]
      end

      before do
        allow(event).to receive(:ps_fields_with_values).and_return(ps_fields_with_values)
      end

      context 'when payload store respond with success' do
        before do
          expect(payload_store_client).to receive(:get_payloads).
            exactly(:once).with(
              ps_fields_with_values.values
            ).and_return(success_response)
        end

        it 'calls the payload store exactly once to resolve payloads' do
          subject.send(:call, event)
        end

        it 'updates the event with resolved payloads' do
          expected_data = {
            'description' => 'Real Long Text',
            'last_name' => 'name',
            'bio' => 'Real Long Text'
          }
          expect { subject.send(:call, event) }.to change { event.data }.
            from(event_data).
            to(expected_data)
        end

        context 'when key is missing in the payload store' do
          let(:service_response_data) do
            [
              double(
                'PS Response Entry',
                attributes: { value: 'Real Long Text', key: 'payload-store:e1759f32' }
              )
            ]
          end

          it 'changes only available keys' do
            expected_data = {
              'description' => 'Real Long Text',
              'last_name' => 'name',
              'bio' => 'payload-store:f24d29d0'
            }
            expect { subject.send(:call, event) }.to change { event.data }.
              from(event_data).
              to(expected_data)
          end
        end
      end

      context 'when payload store respond with failure' do
        before do
          expect(payload_store_client).to receive(:get_payloads).
            exactly(:once).with(
              ps_fields_with_values.values
            ).and_return(failure_response)
        end

        it 'does not modify event' do
          expect { subject.send(:call, event) }.to_not(change { event.data })
        end

        it 'calls ErrorNotifier' do
          expect_any_instance_of(Yes::Core::Utils::ErrorNotifier).to receive(:payload_extraction_failed)
          subject.send(:call, event)
        end
      end
    end
  end
end
