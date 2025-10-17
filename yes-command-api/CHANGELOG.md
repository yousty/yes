# Unreleased
* Bump yousty-eventsourcing dependency to 15.0.1-alpha8
* Add channel log in observability
* Refactor routes.rb
* Fix and update specs

# 2.3.1 - 2025-09-26
* Fix routing configuration

# 2.3.0 - 2025-09-26
* Add OpenTelemetry instrumentation for command handling and event publishing
* Clean up RSpec configuration and test file requires
* Refactor command API specs

# 2.2.0 - 2025.03.27
* Add identity ID to command metadata so that it gets merged into event meta data. For use in process managers that can now use the identity_id as a message bus channel. That way, frontend can track commands executed from a process manager.

# 2.1.0 - 2025.02.05
* Add ability to process commands in the foreground. To do this - add `async=false` param to your query params. `yousty-eventsourcing` v13.3+ is required for this functional. Using `yousty-eventsourcing` less than v13.3 will ignore `async` param.

# 2.0.0 - 2024.10.08
* Officially support pg event store, support for command groups

# 1.0.2 - 2024.04.02
* Fix blank channel param

# 1.0.1 - 2024.04.02
* Extract auth_data helper to jwt_token_auth_client_rails

# 1.0.0 - 2024.03.28
* Breaking change: Allow clerk and yousty jwt token, introduce new auth_data format

# 0.3.2 - 2024.03.01
* Add support for auth_data['principal_id'] once creating a channel for message bus

# 0.3.1 - 2024.02.08
* Relax yousty-eventsourcing version

# 0.3.0 - 2023.10.12
* Remove unused classes

# 0.2.5 - 2023.08.01
* Remove unused classes

# 0.2.4 - 2023.07.28
* Fix default message bus channel name

# 0.2.3 - 2023.07.28
* Pass in scopes as well in auth data

# 0.2.2 - 2023.07.12
* Add Message Bus filters
* Change default channel name to logged in user uuid

# 0.2.1 - 2023.07.04
* Add transaction details once call CommandBus

# 0.2.1 - 2023.07.04
* Add transaction details once call CommandBus

# 0.2.0 - 2023.06.26
* Remove V2 commands api endpoint
