# frozen_string_literal: true

module APIHelpers
  def json
    @json ||= response.parsed_body
  end

  def json_data
    @json_data = json['data']
  end

  def json_data_attributes
    @json_data_attributes =
      json_data.is_a?(Array) ? json_data.first['attributes'] : json_data&.dig('attributes')
  end

  def json_data_relationships
    @json_data_relationships = json_data['relationships']
  end

  def json_meta
    @json_meta = json['meta']
  end

  def json_included
    @json_included = json['included']
  end

  def json_included_ids
    @json_included_ids = json_included.pluck('id')
  end

  RSpec.shared_examples 'successful write response' do
    before do
      subject
    end

    it 'responds with success HTTP status code' do
      expect(response).to have_http_status(:ok)
    end

    it 'has correct content type' do
      expect(response.content_type).to include('application/json; charset=utf-8')
    end

    it 'responds has batch id' do
      expect(response.parsed_body).to have_key('batch_id')
    end
  end

  RSpec.shared_examples 'successful inline write response' do
    before do
      subject
    end

    it 'responds with success HTTP status code' do
      expect(response).to have_http_status(:ok)
    end

    it 'has correct content type' do
      expect(response.content_type).to include('application/json; charset=utf-8')
    end

    it 'responds has command response data' do
      expect(response.parsed_body).to be_a(Array)
    end
  end

  RSpec.shared_examples_for 'authentication failure' do
    before do
      subject
    end

    it 'returns 401' do
      expect(response).to have_http_status(:unauthorized)
    end

    it 'has correct content type' do
      expect(response.content_type).to include('application/json; charset=utf-8')
    end

    it 'has correct error body' do
      expect(response.parsed_body).to include(
        'title' => 'Auth Token Invalid'
      )
    end
  end

  RSpec.shared_examples_for 'authorization failure' do
    let(:errors) { response.parsed_body['details'] }

    before do
      subject
    end

    it 'returns 401' do
      expect(response).to have_http_status(:unauthorized)
    end

    it 'has correct content type' do
      expect(response.content_type).to include('application/json; charset=utf-8')
    end

    it 'has correct error body' do
      expect(response.parsed_body).to include(
        'title' => 'Unauthorized'
      )
    end

    it 'returns correct error message' do
      expect(errors.first['message']).to eq(error_msg)
    end
  end

  RSpec.shared_examples_for 'bad request' do
    before do
      subject
    end

    it 'returns 400' do
      expect(response).to have_http_status(:bad_request)
    end

    it 'has correct content type' do
      expect(response.content_type).to include('application/json; charset=utf-8')
    end

    it 'has correct error body' do
      expect(response.parsed_body).to include(
        'title' => 'Bad request',
        'detail' => expected_details
      )
    end
  end

  RSpec.shared_examples 'unprocessable entity response' do
    let(:errors) { response.parsed_body['errors'] }

    before do
      subject
    end

    it 'responds with Unprocessable Entity HTTP status code' do
      expect(response.status).to eq(422)
    end

    it 'has correct content type' do
      expect(response.content_type).to include('application/json; charset=utf-8')
    end

    it 'returns errors' do
      expect(errors).to_not be_empty
    end

    it 'returns correct error message' do
      expect(errors.first['message']).to eq(error_msg)
    end
  end

  RSpec.shared_examples 'does not run any command' do |errors|
    let(:command_bus) { instance_spy(Yousty::Eventsourcing::CommandBus) }

    before do
      allow(Yousty::Eventsourcing::CommandBus).to receive(:new).and_return(command_bus)
      allow(command_bus).to receive(:call)
    end

    it 'does not run any command' do
      subject

      expect(command_bus).to_not have_received(:call)
    end
  end
end
