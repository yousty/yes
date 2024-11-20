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
- State management for the attribute value

## `change_<attribute>` Method

For each attribute defined on an aggregate, an instance method `change_<attribute>` is automatically added. This method allows you to change the attribute's value by:

1. Instantiating a command with the new value.
2. Calling the command handler to process the command.
3. Publishing the corresponding event if the command is successfully handled.

### Example

Given an aggregate with a `name` attribute:

```ruby
class UserAggregate < Yes::Aggregate
  attribute :name, :string
end
```

You can change the `name` attribute using the `change_name` method:

```ruby
user_aggregate = UserAggregate.new
event = user_aggregate.change_name(name: "New Name")
# event is an instance of PgEventstore::Event if the change is successful
```

This will create a command to change the `name`, process it through the handler, and publish an event reflecting the change. The method returns a `PgEventstore::Event` instance upon success.

## Development

After checking out the repo, run `bin/setup` to install dependencies.

Then run the pg eventstore using docker:

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
