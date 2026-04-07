# frozen_string_literal: true

RSpec.shared_examples 'open telemetry trackable' do
  include_context :opentelemetry

  let(:expected_spans_amount) { 1 }

  let(:expected_spans_kind) { [:internal] }
  let(:expected_spans_name) { ['UnknownName'] }

  let(:extra_attribute_keys) { {} } # { span_name => { 'attribute_name' => 'attribute_value' } }
  let(:default_attribute_keys) { { 'track_sql' => false, 'root_track_sql' => false } }
  let(:expected_attributes_array) do
    # ignore SQL spans
    expected_spans_name.grep_v(/SQL/).map do |span_name|
      { span_name => default_attribute_keys.merge(extra_attribute_keys[span_name] || {}) }
    end
  end

  before do
    subject
  end

  it 'records expected amount of spans' do
    expect(in_memory_exporter.finished_spans.count).to eq(expected_spans_amount)
  end

  it 'records correct span type' do
    expect(in_memory_exporter.finished_spans.pluck(:kind)).to match_array(expected_spans_kind)
  end

  it 'records spans with correct name' do
    expect(in_memory_exporter.finished_spans.pluck(:name)).to match_array(expected_spans_name)
  end

  it 'records spans with correct attributes' do
    aggregate_failures do
      expected_attributes_array.each do |attributes_hash|
        span = in_memory_exporter.finished_spans.find { _1.name == attributes_hash.keys.first }
        expect(span.attributes).to match(attributes_hash.values.first)
      end
    end
  end
end

RSpec.shared_examples 'no open telemetry tracing' do
  include_context :opentelemetry

  let(:returned_result) { nil }

  before do
    Yes::Core.configuration.otl_tracer = nil
  end

  context 'when no tracer is configured' do
    it 'does not record any spans' do
      subject

      expect(in_memory_exporter.finished_spans.count).to eq(0)
    end

    it 'returns correct result' do
      expect(subject).to eq(returned_result)
    end
  end
end
