# frozen_string_literal: true

# Stands in for a consumer action with its own contract: it applies `filter_definition` from a GET
# and opts out of the drop, so it has to authorize what it applies itself.
class ShopExportController < Yes::Read::Api::QueriesController
  skip_before_action :drop_ignored_filter_param, only: :search

  # Authorizes the request params and answers with an empty body.
  #
  # @return [void]
  def search
    request_authorizer.call(params, auth_data)

    render json: { data: [] }.to_json
  end
end
