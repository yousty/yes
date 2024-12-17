# Yes::Aggregate

The `Yes::Aggregate` class provides a DSL for defining event-sourced aggregates.

The DSL provides the following methods for usage inside the `Yes::Aggregate` class:

- `attribute`: automatically generates the necessary commands, events, and handlers for managing your aggregate's state.

## Basic Usage

To define attributes on your aggregate, use the `attribute` method with a name and type:

```ruby
module Users
  class User
    class Aggregate < Yes::Aggregate
      attribute :name, :string
      attribute :email, :email
      attribute :age, :integer
    end
  end
end
```

This will create a fully event-sourced user entity with all necessary components for managing these attributes through commands and events.

Note that when defining an aggregate you need to use the following namespacing / class naming rule: `<Context>::<AggregateName>::Aggregate`.

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

## `can_change_<attribute>?` Method

For each attribute, a `can_change_<attribute>?` method is automatically added. This method allows you to validate whether a change would be successful without actually making the change. It returns `true` if the change would be valid, and `false` otherwise. If the change would be invalid, an error message is stored in the corresponding `<attribute>_change_error` accessor.

### Example

```ruby
module Users
  class User
    class Aggregate < Yes::Aggregate
      attribute :email, :email
    end
  end
end

user = Users::User::Aggregate.new

# Invalid change
user.can_change_email?(email: "invalid-email")  # => false

# Valid change
user.can_change_email?(email: "user@example.com")  # => true
```

## `change_<attribute>` Method

For each attribute defined on an aggregate, an instance method `change_<attribute>` is automatically added. This method allows you to change the attribute's value by:

1. Instantiating a command with the new value.
2. Calling the command handler to process the command.
3. Publishing the corresponding event if the command is successfully handled.

### Example

Given an aggregate with a `name` attribute:

```ruby
module Users
  class User
    class Aggregate < Yes::Aggregate
      attribute :name, :string
    end
  end
end
```

You can change the `name` attribute using the `change_name` method:

```ruby
user_aggregate = Users::User::Aggregate.new
user_aggregate.change_name(name: "New Name") # => PgEventstore::Event
```

In case the change is invalid, the change method will return `false` and the `<attribute>_change_error` accessor will be set to the error message.

```ruby
user_aggregate.change_name(name: "New Name")  # => false
user_aggregate.name_change_error  # => "Name is invalid"
```

## Read Models

For each aggregate there is a corresponding read model (ActiveRecord model) generated that stores its current state. By default, the read model's name is derived from the aggregate's name. For example, `Users::User::Aggregate` will have a read model named `User`.

### Customizing Read Models

You can customize the read model name and visibility using the `read_model` method in your aggregate:

```ruby
module Users
  module User
    class Aggregate < Yes::Aggregate
      # Use a custom read model name and make the read model private (not accessible via read API)
      read_model 'custom_user', public: false

      attribute :email, :email
      attribute :name, :string
    end
  end
end
```

### Attribute Accessors

For each attribute defined in the aggregate, a corresponding accessor method is automatically created. This accessor reads the attribute's value from the read model:

```ruby
user = Users::User::Aggregate.new
user.email # reads email from the read model
user.name # reads name from the read model
```

### Updating Read Model Schema

Whenever you make changes to your aggregates (adding/removing aggregates or attributes), you need to update your read model schema. Use the provided Rails generator:

```shell
rails generate yes:read_models:update
```

This generator will create a migration file that updates the read model schema to match the current state of your aggregates.

Limitation: The generator does not currently support changing attribute types.

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
