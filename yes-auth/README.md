# Yes Auth

Authorization principals and Cerbos integration for the [Yes](https://github.com/yousty/yes) event sourcing framework.

## Overview

`yes-auth` provides ActiveRecord-backed authorization principal models and Cerbos principal data builders. It is designed to work with `yes-core` to provide role-based access control with fine-grained read and write resource access permissions.

### Principal Models

- **User** - represents an authorization principal with roles and resource accesses
- **Role** - named roles that can be assigned to users and resource accesses
- **ReadResourceAccess** - links a principal to a role-based read permission scoped by service, scope, and resource type
- **WriteResourceAccess** - links a principal to a role-based write permission scoped by context and resource type

### Cerbos Integration

- **WriteResourceAccess::PrincipalData** - builds Cerbos principal data from write resource accesses
- **ReadResourceAccess::PrincipalData** - builds Cerbos principal data from read resource accesses

## Installation

Add to your `Gemfile`:

```ruby
gem 'yes-auth'
```

Or if using a monorepo with path references:

```ruby
gem 'yes-auth', path: 'yes-auth'
```

### Auto-Configuration

When loaded in a Rails application, yes-auth automatically configures the Cerbos principal data builders in yes-core:

- `config.cerbos_principal_data_builder` → `Yes::Auth::Cerbos::WriteResourceAccess::PrincipalData`
- `config.cerbos_read_principal_data_builder` → `Yes::Auth::Cerbos::ReadResourceAccess::PrincipalData`

This means you don't need to manually configure these in your initializer — just adding `yes-auth` to your Gemfile is enough.

To override the default builders, set them explicitly in your initializer (after yes-auth's railtie runs):

```ruby
Yes::Core.configure do |config|
  config.cerbos_principal_data_builder = MyCustomPrincipalDataBuilder.method(:call)
end
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `CERBOS_URL` | `cerbos-cluster-ip-service:3593` | Cerbos server address (set via yes-core config) |

## Usage

### Principal Models

```ruby
# Find a user by identity
user = Yes::Auth::Principals::User.find_by(identity_id: 'user-uuid')

# Check roles
user.read_resource_access_authorization_roles
user.write_resource_access_authorization_roles
user.super_admin?

# Access resource permissions
user.read_resource_accesses
user.write_resource_accesses
```

### Cerbos Principal Data

Build principal data for Cerbos authorization checks:

```ruby
# For write operations
write_data = Yes::Auth::Cerbos::WriteResourceAccess::PrincipalData.call(
  identity_id: 'user-uuid'
)
# => { id: 'identity-id', roles: ['manager'], attributes: { write_resource_access: { ... } } }

# For read operations
read_data = Yes::Auth::Cerbos::ReadResourceAccess::PrincipalData.call(
  identity_id: 'user-uuid'
)
# => { id: 'identity-id', roles: ['viewer'], attributes: { read_resource_access: { ... } } }
```

### Configuration

Plug into `yes-core`'s Cerbos authorization by configuring the principal data builder:

```ruby
# config/initializers/yes.rb
Yes::Core.configure do |config|
  config.cerbos_principal_data_builder = Yes::Auth::Cerbos::WriteResourceAccess::PrincipalData
end
```

For read APIs that need read-scoped authorization:

```ruby
Yes::Core.configure do |config|
  config.cerbos_principal_data_builder = Yes::Auth::Cerbos::ReadResourceAccess::PrincipalData
end
```

## Database Schema

The gem expects the following tables to exist:

- `auth_principals_users` - stores user principals
- `auth_principals_roles` - stores named roles
- `auth_principals_read_resource_accesses` - stores read resource access records
- `auth_principals_write_resource_accesses` - stores write resource access records
- A join table for the users-roles HABTM association

## Development

```bash
cd yes-auth
bundle install
bundle exec rspec
```

## Contributing

See the [contributing guide](../CONTRIBUTING.md) for instructions on how to contribute to the Yes framework.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
