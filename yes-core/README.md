# Yes Core

Core event sourcing framework providing the aggregate DSL, commands, events, read models, and supporting infrastructure for the [Yes](https://github.com/yousty/yes) framework.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'yes-core'
```

And then execute:

```bash
bundle install
```

## Usage

See the [root README](../README.md) for the full DSL documentation and usage examples.

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

Set up the EventStore database:

```shell
PG_EVENTSTORE_URI="postgresql://postgres:postgres@localhost:5532/eventstore_test" bundle exec rake pg_eventstore:create pg_eventstore:migrate
```

Set up the test database:

```shell
RAILS_ENV=test bundle exec rake db:create db:migrate
```

### Running Specs

```shell
bundle exec rspec
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yousty/yes.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
