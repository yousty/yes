# Yes Read API

This gem implements an endpoint to query read models.

## Installation

Add a gem to your Gemfile

```ruby
gem 'yes-read-api'
```

and run `bundle install`

## Usage

See the [root README](../README.md) for the full DSL documentation and aggregate definition.

There are a few steps you need to do in order to integrate this gem. In the examples below we assume you have an `Apprenticeship` read model class. The module structure is strict.

- Mount gem's endpoint to use it. Example(in `routes.rb`):

```ruby
Rails.application.routes.draw do
  mount Yes::Read::Api::Engine => '/queries'
end
```

- Define a set of registered models. You can do it as follows (in `application.rb`)

```ruby
config.yes_read_api.read_models = ['apprenticeships']
```

- Define an authorizer for your read model's request:

```ruby
module ReadModels
  module Apprenticeship
    class RequestAuthorizer < Yes::Core::ReadModel::RequestAuthorizer
      def self.call(params, auth_data)
        auth_data['scopes'].include?('admin')
      end
    end
  end
end
```

- Define a filter class for your read model. You can declare various ActiveRecord filters which can be applied to your collection based on request params. Assuming you have a `by_id` scope in your `Apprenticeship` model:

```ruby
module ReadModels
  module Apprenticeship
    class Filter < Yes::Core::ReadModel::Filter
      has_scope :ids do |controller, scope, value|
        scope.by_id(value.split(','))
      end

      private

      def read_model_class
        ::Apprenticeship
      end
    end
  end
end
```

- _Optional._ Define an authorizer for your read model. You can inherit from `Yes::Core::ReadModelAuthorizer` or define your own base class:

```ruby
module ReadModels
  module Apprenticeship
    class Authorizer < ReadModels::Authorizer
      class << self
        def call(record, auth_data)
          raise ReadModels::Authorizer::NotAuthorized, 'You need to be a company admin' unless company_admin?(auth_data)

          true
        end
      end
    end
  end
end
```

Now you can query your read model via `GET /queries/apprenticeships` request.

### Pagination
Read responses are always paginated. You can supply pagination parameter in case you want to change the default

| Name                | Default |
|---------------------|---------|
| page[number]        |    1    |
| page[size]          |    20   |
| page[include_total] |  false  |

The read response includes pagination information in the following headers

| Name       | Description                                                                                                      |
|------------|------------------------------------------------------------------------------------------------------------------|
| X-Page     |                                                    page number                                                   |
| X-Per-Page |                                                     page size                                                    |
| X-Total    | Total number of items.  By default not included(null) If you need a total number set `page[include_total]` to `true` |

By default pagination is using `countless_minimal` mode.
The `X-Total` header is not returned in the response. Count query is not produced to DB.

You can change this behavior per each request by adding `page[include_total]=true` params to the request query.

If you wish to change the default behavior globally, so `X-Total` header is returned for the every request response by default, you can set globally `Pagy::DEFAULT[:countless_minimal] = false` or example in the `pagy_initializer.rb`. In this case `page[include_total]` param is ignored.

More you can read here: [Pagy Countless](https://ddnexus.github.io/pagy/docs/extras/countless/)



## Development

### Prerequisites

- Docker and Docker Compose
- Ruby >= 3.2.0
- Bundler

### Setup

Start PostgreSQL from the **repository root**:

```shell
docker compose up -d
```

Install dependencies:

```shell
bundle install
```

Set up the test database:

```shell
RAILS_ENV=test bundle exec rake db:create db:migrate
```

The `.env` file at `spec/dummy/.env` is loaded automatically and contains JWT test keys and database configuration.

### Running Specs

```shell
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yousty/yes.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
