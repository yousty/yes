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
end
