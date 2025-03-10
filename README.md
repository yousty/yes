# Yes::Aggregate

The `Yes::Aggregate` class provides a DSL for defining event-sourced aggregates.

## Overview

The DSL provides the following methods for usage inside the `Yes::Aggregate` class:

- `attribute`: automatically generates the necessary commands, events, and handlers for managing your aggregate's state.
- `read_model`: allows you to specify a custom read model name and visibility.
- `parent`: allows you to specify a parent aggregate.
- `primary_context`: allows you to specify the primary context for the aggregate.

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

**Limitation: The generator does not currently support changing attribute types.**


### Command and Read APIs

In case you have the command api mounted to your application, your aggregate's commands will be available on the command api.

In case you have the read api mounted to your application, the default read model will be available on the read api, unless you marked it as private. 

Note that you will need to create the necessary authorizers.



## Development

After checking out the repo, run `bin/setup` to install dependencies.

Then run pg eventstore using docker:

```shell
docker compose up
```

To setup pg eventstore and dummy app development and test dbs run the `setup_db` script:

```shell
./bin/setup_db
```

Now you can enter a dev console by running 

```shell
rails c
```

To get familiar with `Yes` you can play around with the existing aggregates in the dummy app.

Example:

```ruby
user = Users::User::Aggregate.new
user.change_name(name: "John Doe")
user.name # => "John Doe"
User.last.name # => "John Doe"
```

The dummy app has the command and read apis monted, so you can play around with those too.
Just run 

```shell
rails s
```

to start the dummy app server.

You need to set the public and private key environment variables for the jwt token auth. Example:

```shell
export JWT_TOKEN_AUTH_PUBLIC_KEY=2f8c6129d816cf51c374bc7f08c3e63ed156cf78aefb4a6550d97b87997977ee
export JWT_TOKEN_AUTH_PRIVATE_KEY=12345678901234567890123456789012
```

You can then generate the auth token using the following ruby code:

```ruby
require 'jwt'
require 'rbnacl'

private_key = RbNaCl::Signatures::Ed25519::SigningKey.new(
  ENV['JWT_TOKEN_AUTH_PRIVATE_KEY']
)

identity_id = "<some uuid>"
JWT.encode(
  {identity_id:}.merge(exp: 2.years.from_now.to_i), private_key, 'ED25519'
)
```

Test firying a command:

```shell
curl --location 'http://127.0.0.1:3000/commands' \                                                                                   130 ↵
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer <your auth token>>' \
--data '{
  "commands": [{
    "subject": "User",
    "context": "Test",
    "command": "ChangeName",
    "data": {
      "user_id": "47330036-7246-40b4-a3c7-7038df508774",
      "name": "Judydoody Doodle"   
    }
  }]
}'
```

Test reading users:

```shell
curl --rl --location --globoff 'http://127.0.0.1:3000/queries/users' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer <your auth token>>'
```



To run specs of any of the yes gems, enter their directory and run 

```shell
rspec
```

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to `gem.fury.io`. In order to push new releases you need to provide `GEM_FURY_PUSH_TOKEN` env variable.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/yousty/yousty-eventsourcing.
