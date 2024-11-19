# Yes::Aggregate

The `Yes::Aggregate` class provides a DSL for defining event-sourced aggregates.

The DSL provides the following methods for usage inside the `Yes::Aggregate` class:

- `attribute`: automatically generates the necessary commands, events, and handlers for managing your aggregate's state.

## Basic Usage

To define attributes on your aggregate, use the `attribute` method with a name and type:

```ruby
class UserAggregate < Yes::Aggregate
  attribute :name, :string
  attribute :email, :email
  attribute :age, :integer
end
```

This will create a fully event-sourced user entity with all necessary components for managing these attributes through commands and events.

## Available Types

The attribute system supports various types, for example:
- `:string` - For text values
- `:email` - For email addresses
- `:uuid` - For UUID values
- `:integer` - For numeric values

For the full list of types see [lib/yes/type_lookup.rb](lib/yes/type_lookup.rb)

## Generated Components

For each attribute, the system automatically generates:
- A command for updating the attribute
- An event for recording attribute changes
- A handler for processing the command
- State management for the attribute value (later)


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bundle exec rspec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

Run the pg eventstore using docker:

```shell
docker compose up
```

To setup pg eventstore run the `setup_db` script:

```shell
./bin/setup_db
```

Now you can enter a dev console by running `bin/console` or run tests by running the `rspec` command.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to `gem.fury.io`. In order to push new releases you need to provide `GEM_FURY_PUSH_TOKEN` env variable.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yousty/yousty-eventsourcing.
