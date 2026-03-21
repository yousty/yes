# frozen_string_literal: true

RSpec.describe ReadModels::JobApp::Filter do
  let(:filter_instance) { described_class.new(options) }
  let(:options) { {} }

  before { JobApp.delete_all }

  describe '.call' do
    subject { filter_instance.call }

    let(:job_app1) { JobApp.create!(id: SecureRandom.uuid, name: 'app1') }
    let(:job_app2) { JobApp.create!(id: SecureRandom.uuid, name: 'app2') }
    let(:job_app3) { JobApp.create!(id: SecureRandom.uuid, name: 'app3') }

    let(:job_apps) do
      [job_app1, job_app2, job_app3]
    end

    context 'when options[:filters] is not set' do
      it 'returns all read model records' do
        expect(subject).to eq(job_apps.sort_by(&:id))
      end
    end

    context 'when options[:filters] is set' do
      let(:options) { { filters: { by_name: 'app2' } } }

      it 'returns filtered read model records' do
        expect(subject).to eq([job_app2])
      end
    end

    context 'when advanced filter is used' do
      let(:filter_instance) { described_class.new(options, type: :advanced) }

      context 'when options[:filter_definition] is blank' do
        let(:options) { {} }

        it 'returns all read model records' do
          expect(subject).to eq(job_apps.sort_by(&:id))
        end
      end

      context 'when options[:filter_definition] is set' do
        let(:options) { { filter_definition: { type: 'filter_set', logical_operator: 'and', filters: [first_filter, second_filter] } } }
        let(:first_filter) { { type: 'filter', attribute: 'names', operator: 'is', value: 'app1,app2' } }
        let(:second_filter) { { type: 'filter', attribute: 'ids', operator: 'is_not', value: [job_app1.id, job_app3.id].join(',') } }

        it 'returns filtered read model records' do
          expect(subject).to eq([job_app2])
        end
      end
    end
  end
end
