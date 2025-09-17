## [Unreleased]

# 1.1.0 - 2025-09-17
* Bring read API up to date with latest specifications and setup
* Add persisted filters to read API functionality
* Add rake task for loading structure.sql
* Clean up Gemfiles and database setup
* Switch dummy app to SQL schema format for better database consistency
* Update specs to use real models instead of mocks for improved test reliability
* Improve command handling implementation following SOLID principles
* Replace unique index with PostgreSQL trigger for concurrent update prevention
* Refactor CommandHandling module for better maintainability

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
