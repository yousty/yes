# Yousty::Read::Api

This gem implements an endpoint to query read models.

## Installation

Add a gem to your Gemfile

```ruby
source 'https://gem.fury.io/yousty-ag/' do
  gem 'yousty-read-api'
end
```

and run `bundle install`

## Usage

There are few steps you need to do in order to integrate this gem. In the examples bellow I assume you have an `Apprenticeship` read model class. Modules structure is strict.

- Mount gem's endpoint to use it. Example(in `routes.rb`):

```ruby
Rails.application.routes.draw do
  mount Yousty::Read::Api::Engine => '/queries'
end
```

- Define a set of registered models. You can do it as follows(in `application.rb`)

```ruby
config.yousty_read_api.read_models = ['apprenticeships']
```

- Define an authorizer for your read model's request:

```ruby
module ReadModels
  module Apprenticeship
    class RequestAuthorizer < Yousty::Eventsourcing::ReadRequestAuthorizer
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
    class Filter < Yousty::Eventsourcing::ReadModelFilter
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

- _Optional._ Define authorizer of your read model:

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

More you can read here: [PAgy Countless](https://ddnexus.github.io/pagy/docs/extras/countless/)



## Development

You will have to install Docker first. It is needed to run services, needed for the development of this gem. Then you can start them using this command:

```shell
docker-compose up
```

Make sure you have created a database and run migrations:
```shell
rails db:create
rails db:migrate
rails db:migrate RAILS_ENV=test
```

Now you can enter a dev console by running `rails c` or run tests by running the `rspec` command.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to `gem.fury.io`. In order to push new releases you need to provide `GEM_FURY_PUSH_TOKEN` env variable.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yousty/yousty-read-api.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
