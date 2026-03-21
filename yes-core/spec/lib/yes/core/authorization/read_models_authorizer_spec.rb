# frozen_string_literal: true

RSpec.describe Yes::Core::Authorization::ReadModelsAuthorizer do
  describe '.call' do
    subject { described_class.call(read_model_name, records, auth_data) }

    let(:auth_data) { {} }
    let(:read_model_name) { 'job_app' }

    context 'when all records are authorized' do
      let(:records) do
        [
          FactoryBot.create(:job_app),
          FactoryBot.create(:job_app),
          FactoryBot.create(:job_app)
        ]
      end

      it 'does not raise any error' do
        expect { subject }.not_to raise_error
      end
    end

    context 'when some record is not authorized' do
      let(:records) do
        [
          FactoryBot.create(:job_app),
          FactoryBot.build(:job_app),
          FactoryBot.create(:job_app)
        ]
      end

      it 'raises NotAuthorized error' do
        expect { subject }.to(
          raise_error(Yes::Core::Authorization::ReadModelsAuthorizer::NotAuthorized)
        )
      end
    end
  end
end
