## [Unreleased]

# 1.3.0 - 2025-11-05
* Add 'own' filter implementation to read API

# 1.2.0 - 2025-10-17
* Bump yousty-eventsourcing dependency to 15.0.1-alpha8
* Add OpenTelemetry tracing to read API
* Refactor read_models_unauthorized_response - return error message as details - to keep backward compatibility with existing clients

# 1.1.1 - 2025-09-17
* Ensure filters hash is initialized in queries controller

# 1.1.0 - 2025-09-17
* Add persisted filters to read API functionality

# 1.0.1 - 2024.04.02
* Extract auth_data helper to jwt_token_auth_client_rails

# 1.0.0 - 2024.04.02
* Breaking change: Allow clerk and yousty jwt token, introduce new auth_data format

## [0.1.4] - 2024-02-08
 * Relax `yousty-eventsourcing` version

## [0.1.3] - 2023-09-01
 * Add support for countless pagination mode
 * Use countless mode as default
 * Add `include_total` param to pagination
 * Add conditional `X-Total` header to response

## [0.1.2] - 2023-08-24
* Add read model whitelisting
* Add basic readme

## [0.1.1] - 2023-08-18

* Fix CI build

## [0.1.0] - 2023-08-18

* Add queries read endpoint
* Initialize project, generated rails plugin
