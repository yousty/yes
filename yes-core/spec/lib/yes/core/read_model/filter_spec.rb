# frozen_string_literal: true

RSpec.describe Yes::Core::ReadModel::Filter do
  let(:instance) { ReadModels::JobApp::Filter.new(options) }
  let(:options) { {} }

  describe '#call' do
    subject { instance.call }

    before { JobApp.delete_all }

    let!(:job_app_1) { FactoryBot.create(:job_app, name: 'first') }
    let!(:job_app_2) { FactoryBot.create(:job_app, name: 'second') }
    let!(:job_app_3) { FactoryBot.create(:job_app, name: 'third') }
    let!(:job_app_4) { FactoryBot.create(:job_app, name: 'fourth') }

    context 'when options are empty' do
      it 'returns all records, sorted by id' do
        aggregate_failures do
          is_expected.to eq([job_app_1, job_app_2, job_app_3, job_app_4].sort_by(&:id))
          is_expected.to be_a(ActiveRecord::Relation)
        end
      end
    end

    context 'when :filters option is provided' do
      let(:options) { { filters: { ids: [job_app_1.id, job_app_2.id].join(',') } } }

      it 'filters the result' do
        aggregate_failures do
          is_expected.to eq([job_app_1, job_app_2].sort_by(&:id))
          is_expected.to be_a(ActiveRecord::Relation)
        end
      end
    end

    context 'when :order option is provided' do
      let(:options) { { order: { name: direction } } }
      let(:direction) { 'asc' }

      context 'when direction value is "asc"' do
        it 'sorts records in ascending order' do
          aggregate_failures do
            is_expected.to eq([job_app_1, job_app_4, job_app_2, job_app_3])
            is_expected.to be_a(ActiveRecord::Relation)
          end
        end
      end

      context 'when direction value is "desc"' do
        let(:direction) { 'desc' }

        it 'sorts records in ascending order' do
          aggregate_failures do
            is_expected.to eq([job_app_3, job_app_2, job_app_4, job_app_1])
            is_expected.to be_a(ActiveRecord::Relation)
          end
        end
      end

      context 'when direction value is "0"' do
        let(:direction) { '0' }

        it 'sorts records in ascending order' do
          aggregate_failures do
            is_expected.to eq([job_app_1, job_app_4, job_app_2, job_app_3])
            is_expected.to be_a(ActiveRecord::Relation)
          end
        end
      end

      context 'when direction value is "1"' do
        let(:direction) { '1' }

        it 'sorts records in ascending order' do
          aggregate_failures do
            is_expected.to eq([job_app_3, job_app_2, job_app_4, job_app_1])
            is_expected.to be_a(ActiveRecord::Relation)
          end
        end
      end
    end

    context 'when :order and :filters options are provided' do
      let(:options) { { order: { name: 'desc' }, filters: { ids: [job_app_1.id, job_app_4.id].join(',') } } }

      it 'returns filtered, properly ordered result' do
        aggregate_failures do
          is_expected.to eq([job_app_4, job_app_1])
          is_expected.to be_a(ActiveRecord::Relation)
        end
      end
    end

    context 'when advanced filter is used' do
      let(:instance) { ReadModels::JobApp::Filter.new(options, type: :advanced) }
      let(:logical_operator) { 'and' }
      let(:scope) { nil }
      let(:options) do
        {
          filter_definition: {
            type: 'filter_set',
            logical_operator:,
            filters: [first_filter, second_filter],
            scope:
          }.compact
        }
      end
      let(:first_filter) do
        {
          type: 'filter',
          attribute: 'names',
          operator: 'is',
          value: 'first,third,fifth'
        }
      end
      let(:second_filter) do
        {
          type: 'filter',
          attribute: 'ids',
          operator: 'is_not',
          value: [job_app_1.id, job_app_4.id].join(',')
        }
      end

      # redundant, but for more readable tests
      let(:matching_only_first_filter) { job_app_1 }
      let(:matching_only_second_filter) { job_app_2 }
      let(:matching_both_filters) { job_app_3 }
      let(:not_matching_any_filter) { job_app_4 }
      let!(:matching_both_filters_but_not_authorized) { FactoryBot.create(:job_app, name: 'fifth') }

      context 'when logical operator is "and"' do
        it 'returns records that match all filters' do
          is_expected.to match_array([matching_both_filters, matching_both_filters_but_not_authorized])
        end

        context 'when authorization scope is provided' do
          let(:scope) { { ids: [job_app_1.id, job_app_2.id, job_app_3.id, job_app_4.id].join(',') } }

          it 'returns only authorized subset of records' do
            is_expected.to match_array([matching_both_filters])
          end
        end
      end

      context 'when logical operator is "or"' do
        let(:logical_operator) { 'or' }

        it 'returns records that match either filter' do
          is_expected.to match_array(
            [
              matching_only_first_filter,
              matching_only_second_filter,
              matching_both_filters,
              matching_both_filters_but_not_authorized
            ]
          )
        end

        context 'when authorization scope is provided' do
          let(:scope) { { ids: [job_app_1.id, job_app_2.id, job_app_3.id, job_app_4.id].join(',') } }

          it 'returns only authorized subset of records' do
            is_expected.to match_array(
              [
                matching_only_first_filter,
                matching_only_second_filter,
                matching_both_filters
              ]
            )
          end
        end
      end
    end
  end
end
