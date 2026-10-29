# frozen_string_literal: true

# Stands in for a consumer controller that adds its own action to the queries controller.
class ShopSearchController < Yes::Read::Api::QueriesController
  # Authorizes the request params and answers with an empty body.
  #
  # @return [void]
  def search
    request_authorizer.call(params, auth_data)

    render json: { data: [] }.to_json
  end
end
