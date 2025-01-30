# Unreleased

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
