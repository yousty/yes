# frozen_string_literal: true

RSpec.describe 'Yes::Read::Api::QueriesController', type: :request do
  include_context :request_header_variables

  describe 'GET /queries/:read_model' do
    subject do
      get("/queries/#{read_model}", params:, headers: request_headers)
    end

    let(:read_model) { 'apprenticeships' }
    let(:params) { {} }
    let(:auth_user_uuid) { SecureRandom.uuid }

    context 'when unauthenticated/unauthorized' do
      context 'when access token is missing' do
        let(:access_token) { nil }

        it_behaves_like 'authentication token missing'
      end
    end

    context 'when no request authorizer exists' do
      let(:read_model) { 'companies' }
      let(:identity_id) { auth_user_uuid }
      let(:host) { 'www.xyz.ch' }
      let(:access_token) { jwt_sign_in(host:, identity_id:) }

      it_behaves_like 'unauthorized response' do
        let(:details) { 'Not allowed' }
      end
    end

    context 'when authenticated and authorized' do
      let(:identity_id) { auth_user_uuid }
      let(:host) { 'www.xyz.ch' }
      let(:access_token) { jwt_sign_in(host:, identity_id:) }

      context 'when requested read model does not exist' do
        let(:read_model) { 'not_existing' }

        it 'raises NotImplementedError' do
          subject
          expect(response.status).to eq(500)
        end
      end

      context 'when requested read model exists' do
        let(:read_model) { 'apprenticeships' }

        context 'when access of records unauthorized' do
          let!(:apprenticeship) { FactoryBot.create(:apprenticeship) }

          before do
            allow(ReadModels::Authorizer).to receive(:company_admin?).and_return(false)
          end

          it_behaves_like 'unauthorized response' do
            let(:details) { 'You need to be a company admin' }
          end
        end

        context 'when record access authorized' do
          it 'returns empty data response' do
            subject

            expect(json_data).to be_empty
          end

          context 'when no records exist' do
            it_behaves_like 'correctly paginated response' do
              let(:page) { '1' }
              let(:total) { '0' }
              let(:per_page) { '20' }
            end
          end

          context 'when records exist' do
            let!(:apprenticeship) { FactoryBot.create(:apprenticeship, company:) }
            let!(:apprenticeship1) { FactoryBot.create(:apprenticeship, company:) }
            let!(:apprenticeship2) { FactoryBot.create(:apprenticeship, company:) }
            let!(:company) { FactoryBot.create(:company) }

            let!(:apprenticeship3) do
              FactoryBot.create(:apprenticeship, company: company1, dropout_enabled: true)
            end
            let(:company1) { FactoryBot.create(:company) }

            context 'when filter_id is provided' do
              before do
                subject
              end

              let(:params) { { filter_id: persisted_filter.id } }
              let(:persisted_filter) do
                FactoryBot.create(
                  :persisted_filter,
                  body: {
                    filter_definition: {
                      type: 'filter_set',
                      filters: [
                        { type: 'filter', value: apprenticeship.id, operator: 'is', attribute: 'ids' },
                        { type: 'filter', value: company1.id, operator: 'is', attribute: 'company_ids' }
                      ],
                      logical_operator: 'or'
                    }
                  }
                )
              end

              it 'returns correct records' do
                expect(json_data.map { |record| record['id'] }).to match_array(
                  [apprenticeship.id, apprenticeship3.id]
                )
              end
            end

            context 'when no filter params are given' do
              before do
                subject
              end

              it 'returns correct records' do
                expect(json_data.map { |record| record['id'] }).to match_array(
                  [apprenticeship.id, apprenticeship1.id, apprenticeship2.id, apprenticeship3.id]
                )
              end

              it 'does not include associated company records' do
                expect(json.keys).to_not include('included')
              end

              it_behaves_like 'correctly paginated response' do
                let(:page) { '1' }
                let(:total) { '4' }
                let(:per_page) { '20' }
              end
            end

            context 'when OpenTelemetry tracer is configured' do
              include_context :opentelemetry_memory_exporter

              before do
                Yousty::Eventsourcing.config.otl_tracer = OpenTelemetry.tracer_provider.tracer('SpecTracer')

                subject
              end

              it_behaves_like 'open telemetry trackable' do
                let(:expected_spans_name) { ['Request Yes::Read::Api::QueriesController'] }
                let(:expected_spans_kind) { [:client] }
                let(:expected_spans_amount) { 1 }
                let(:default_attribute_keys) { {} }
                let(:extra_attribute_keys) do
                  {
                    'Request Yes::Read::Api::QueriesController' => {
                      'auth_token' => "Bearer #{access_token}",
                      'params' => { model: 'apprenticeships' }.to_json,
                      'auth_data' => JWT.decode(access_token.gsub('Bearer ', access_token), nil, false).to_json
                    }
                  }
                end
              end
            end

            context 'when filters params are given' do
              before do
                subject
              end

              context 'when filter by ids' do
                let(:params) { { filters: { ids: [apprenticeship.id, apprenticeship1.id].join(',') } } }

                it 'returns correct records' do
                  expect(json_data.map { |record| record['id'] }).to match_array(
                    [apprenticeship.id, apprenticeship1.id]
                  )
                end

                it 'does not include associated company records' do
                  expect(json.keys).to_not include('included')
                end

                it_behaves_like 'correctly paginated response' do
                  let(:page) { '1' }
                  let(:total) { '2' }
                  let(:per_page) { '20' }
                end
              end

              context 'when filter by dropout enabled' do
                let(:params) { { filters: { dropout_enabled: true } } }

                it 'returns correct records' do
                  expect(json_data.map { |record| record['id'] }).to match_array(
                    [apprenticeship3.id]
                  )
                end

                it 'does not include associated company records' do
                  expect(json.keys).to_not include('included')
                end

                it_behaves_like 'correctly paginated response' do
                  let(:page) { '1' }
                  let(:total) { '1' }
                  let(:per_page) { '20' }
                end
              end

              context 'when order filter is provided' do
                let(:params) { { order: { created_at: 'desc' } } }

                it 'returns records, sorted by the given filter' do
                  expect(json_data.pluck('id')).to(
                    eq([apprenticeship3.id, apprenticeship2.id, apprenticeship1.id, apprenticeship.id])
                  )
                end
              end

              context 'when order filter and filtering filter are provided' do
                before do
                  subject
                end

                let(:params) do
                  { filters: { ids: [apprenticeship.id, apprenticeship1.id].join(',') }, order: { created_at: 'desc' } }
                end

                it 'sorts and filters results according to them' do
                  expect(json_data.pluck('id')).to eq([apprenticeship1.id, apprenticeship.id])
                end
              end
            end

            context 'when include params are given' do
              before do
                subject
              end

              let(:params) { { include: 'company' } }

              it 'returns correct records' do
                expect(json_data.map { |record| record['id'] }).to match_array(
                  [apprenticeship.id, apprenticeship1.id, apprenticeship2.id, apprenticeship3.id]
                )
              end

              it 'includes associated company records' do
                expect(json['included'].pluck('id', 'type')).to match_array(
                  [
                    [company.id, 'companies'],
                    [company1.id, 'companies']
                  ]
                )
              end

              it_behaves_like 'correctly paginated response' do
                let(:page) { '1' }
                let(:total) { '4' }
                let(:per_page) { '20' }
              end
            end
          end
        end
      end
    end
  end

  describe 'POST /queries/:read_model' do
    subject do
      post("/queries/#{read_model}", params: params.to_json, headers: request_headers)
    end

    let(:read_model) { 'apprenticeships' }
    let(:params) { {} }
    let(:auth_user_uuid) { SecureRandom.uuid }

    context 'when unauthenticated/unauthorized' do
      context 'when access token is missing' do
        let(:access_token) { nil }

        it_behaves_like 'authentication token missing'
      end
    end

    context 'when no request authorizer exists' do
      let(:read_model) { 'companies' }
      let(:identity_id) { auth_user_uuid }
      let(:host) { 'www.xyz.ch' }
      let(:access_token) { jwt_sign_in(host:, identity_id:) }

      it_behaves_like 'unauthorized response' do
        let(:details) { 'Not allowed' }
      end
    end

    context 'when authenticated and authorized' do
      let(:identity_id) { auth_user_uuid }
      let(:host) { 'www.xyz.ch' }
      let(:access_token) { jwt_sign_in(host:, identity_id:) }

      context 'when requested read model does not exist' do
        let(:read_model) { 'not_existing' }

        it 'raises NotImplementedError' do
          subject
          expect(response.status).to eq(500)
        end
      end

      context 'when requested read model exists' do
        let(:read_model) { 'apprenticeships' }

        context 'when access of records unauthorized' do
          let!(:apprenticeship) { FactoryBot.create(:apprenticeship) }

          before do
            allow(ReadModels::Authorizer).to receive(:company_admin?).and_return(false)
          end

          it_behaves_like 'unauthorized response' do
            let(:details) { 'You need to be a company admin' }
          end
        end

        context 'when record access authorized' do
          it 'returns empty data response' do
            subject

            expect(json_data).to be_empty
          end

          context 'when no records exist' do
            it_behaves_like 'correctly paginated response' do
              let(:page) { '1' }
              let(:total) { '0' }
              let(:per_page) { '20' }
            end
          end

          context 'when records exist' do
            let!(:apprenticeship) { FactoryBot.create(:apprenticeship, company:) }
            let!(:apprenticeship1) { FactoryBot.create(:apprenticeship, company:) }
            let!(:apprenticeship2) { FactoryBot.create(:apprenticeship, company:) }
            let!(:company) { FactoryBot.create(:company) }

            let!(:apprenticeship3) do
              FactoryBot.create(:apprenticeship, company: company1, dropout_enabled: true)
            end
            let(:company1) { FactoryBot.create(:company) }

            context 'when no filter params are given' do
              before do
                subject
              end

              it 'returns correct records' do
                expect(json_data.map { |record| record['id'] }).to match_array(
                  [apprenticeship.id, apprenticeship1.id, apprenticeship2.id, apprenticeship3.id]
                )
              end

              it 'does not include associated company records' do
                expect(json.keys).to_not include('included')
              end

              it_behaves_like 'correctly paginated response' do
                let(:page) { '1' }
                let(:total) { '4' }
                let(:per_page) { '20' }
              end
            end

            context 'when filters params are given' do
              before do
                subject
              end

              let(:params) do
                {
                  filter_definition: {
                    type: 'filter_set',
                    logical_operator: 'or',
                    filters: [
                      {
                        type: 'filter',
                        attribute: 'ids',
                        operator: 'is',
                        value: [apprenticeship.id, apprenticeship1.id].join(',')
                      },
                      {
                        type: 'filter',
                        attribute: 'dropout_enabled',
                        operator: 'is',
                        value: true
                      }
                    ]
                  }
                }
              end

              it 'returns correct records' do
                expect(json_data.map { |record| record['id'] }).to match_array(
                  [apprenticeship.id, apprenticeship1.id, apprenticeship3.id]
                )
              end

              context 'when filter definition is invalid' do
                let(:params) do
                  {
                    filter_definition: {
                      type: 'filter_set',
                      logical_operator: 'xor',
                      filters: [
                        {
                          type: 'filter',
                          attribute: 'ids',
                          operator: 'is',
                          value: [apprenticeship.id, apprenticeship1.id].join(',')
                        },
                        {
                          type: 'filter',
                          attribute: 'dropout_enabled',
                          operator: 'is',
                          value: true
                        }
                      ]
                    }
                  }
                end

                it 'returns 422' do
                  subject
                  expect(response.status).to eq(422)
                end
              end
            end

            context 'when OpenTelemetry tracer is configured' do
              include_context :opentelemetry_memory_exporter

              let(:params) do
                {
                  filter_definition: {
                    type: 'filter_set',
                    logical_operator: 'or',
                    filters: [
                      {
                        type: 'filter',
                        attribute: 'ids',
                        operator: 'is',
                        value: [apprenticeship.id, apprenticeship1.id].join(',')
                      },
                      {
                        type: 'filter',
                        attribute: 'dropout_enabled',
                        operator: 'is',
                        value: true
                      }
                    ]
                  }
                }
              end

              before do
                Yousty::Eventsourcing.config.otl_tracer = OpenTelemetry.tracer_provider.tracer('SpecTracer')

                subject
              end

              it_behaves_like 'open telemetry trackable' do
                let(:expected_spans_name) { ['Request Yes::Read::Api::QueriesController'] }
                let(:expected_spans_kind) { [:client] }
                let(:expected_spans_amount) { 1 }
                let(:default_attribute_keys) { {} }
                let(:extra_attribute_keys) do
                  {
                    'Request Yes::Read::Api::QueriesController' => {
                      'auth_token' => "Bearer #{access_token}",
                      'params' => params.to_json,
                      'auth_data' => JWT.decode(access_token.gsub('Bearer ', access_token), nil, false).to_json
                    }
                  }
                end
              end
            end

            context 'when include params are given' do
              before do
                subject
              end
              let(:params) { { include: 'company' } }

              it 'returns correct records' do
                expect(json_data.map { |record| record['id'] }).to match_array(
                  [apprenticeship.id, apprenticeship1.id, apprenticeship2.id, apprenticeship3.id]
                )
              end

              it 'includes associated company records' do
                expect(json['included'].pluck('id', 'type')).to match_array(
                  [
                    [company.id, 'companies'],
                    [company1.id, 'companies']
                  ]
                )
              end

              it_behaves_like 'correctly paginated response' do
                let(:page) { '1' }
                let(:total) { '4' }
                let(:per_page) { '20' }
              end
            end
          end
        end
      end
    end
  end
end
