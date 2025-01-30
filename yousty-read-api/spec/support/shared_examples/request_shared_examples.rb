# frozen_string_literal: true

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

RSpec.shared_examples_for 'authentication token missing' do
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
                                      'title' => 'Auth Token Invalid',
                                      'details' => 'Authentication token missing'
                                    )
  end
end

RSpec.shared_examples_for 'unauthorized response' do
  let(:details) { 'Not allowed' }

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
                                      'title' => 'Unauthorized',
                                      'details' => details
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
end

RSpec.shared_examples 'correctly paginated response' do
  let(:page) { '1' }
  let(:total) { '2' }
  let(:per_page) { '1' }

  it 'has returns total pagination header' do
    subject

    expect(response.headers['X-Total']).to eq ""
  end

  it 'has correct per page pagination header' do
    subject

    expect(response.headers['X-Per-Page']).to eq per_page
  end

  it 'has correct page pagination header' do
    subject

    expect(response.headers['X-Page']).to eq page
  end

  context 'when requested total count' do
    let(:params) { super().merge(page: { include_total: 'true' }) }

    it 'has correct total pagination header' do
      subject

      expect(response.headers['X-Total']).to eq total
    end
  end
end
