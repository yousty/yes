# frozen_string_literal: true

ApiPagination.configure do |config|
  # If you have more than one gem included, you can choose a paginator.
  config.paginator = :pagy # or :will_paginate

  # By default, this is set to 'Total'
  config.total_header = 'X-Total'

  # By default, this is set to 'Per-Page'
  config.per_page_header = 'X-Per-Page'

  # Optional: set this to add a header with the current page number.
  config.page_header = 'X-Page'

  # Optional: set this to add other response format. Useful with tools that define :jsonapi format
  config.response_formats = [:json, :xml, :jsonapi]

  config.page_param do |params|
    params.dig(:page, :number)
  end

  config.per_page_param do |params|
    params.dig(:page, :size)
  end

  # Optional: Include the total and last_page link header
  # By default, this is set to true
  # Note: When using kaminari, this prevents the count call to the database
  config.include_total = true
end

Pagy::DEFAULT[:max_per_page] = 100
Pagy::DEFAULT[:countless_minimal] = true
