# Unreleased

# 0.23.2 - 2026-01-28
- Add nullable value support for command and event payload attributes via `nullable: true` option
- Refactor command and event class resolvers to use pattern matching for optional/nullable combinations
- Add comprehensive specs for nullable attribute support in commands and events

# 0.23.1 - 2025-11-11
- Refactor metadata handling to use CommandHandler for proper event metadata merging

# 0.23.0 - 2025-11-11
- Add metadata option support to command DSL

# 0.23.1 - 2025-11-11
- Refactor metadata handling to use CommandHandler for proper event metadata merging

# 0.23.0 - 2025-11-11
- Add metadata option support to command DSL

# 0.22.2 - 2025-11-03
- Fix event type naming for draft and edit template events to include Draft/EditTemplate suffix

# 0.22.1 - 2025-10-28
- Update revision guard error classes to inherit from Yes::Core::Error
- Update DSL error classes to inherit from Yes::Core::Error

# 0.22.0 - 2025-10-25
- Refactor encryption to apply at command/payload level instead of attribute level
- Update terminology from 'encrypted' to 'encrypt' in read model updater

# 0.21.0 - 2025-10-24
- Add encrypted attribute support to aggregate attributes and commands
- Add encryption_schema class method generation for events with encrypted attributes
- Add populate_encrypted_attributes method to CommandDefiner
- Propagate encrypted option through command shortcuts

# 0.20.3 - 2025-10-23
- Move RESERVED_KEYS constant inside Command class

# 0.20.2 - 2025-10-23
- Add es_encrypted to reserved keys in Command class

# 0.20.1 - 2025-10-23
- Fix payload store check to handle non-string values in ReadModelUpdater

# 0.20.0 - 2025-10-23
- Add payload resolution support to ReadModelUpdater for handling large payloads stored externally
- Add inline mode support to CommandProcessor to support command execution without notifiers

# 0.19.0 - 2025-10-22
- Add OpenTelemetry instrumentation to CommandProcessor

# 0.18.3 - 2025-10-22
- Revert string key support from PayloadProxy

# 0.18.2 - 2025-10-22
- Handle RecordNotFound in ReadModelRevisionGuard reload

# 0.18.1 - 2025-10-22
- Add string key support to PayloadProxy for event replay compatibility

# 0.18.0 - 2025-10-21
- Add aggregate shortcuts functionality for Rails console to provide convenient shortcut aliases for aggregate classes
- Enable aggregate shortcuts automatically when Rails console starts
- Support custom abbreviations via YAML configuration file

# 0.17.1 - 2025-10-20
- Add draft parameter support to read model registration

# 0.17.0 - 2025-10-17
- Fixed command payload cloning in command handler to prevent mutating the original payload'

# 0.16.0 - 2025-10-17
* Bump yousty-eventsourcing dependency to 15.0.1-alpha8
* Add observability support in the CommandBus

## [0.15.1] - 2025-10-15

### Changed
- Read model rebuilder: Reset revision to -1 when remove is false

## [0.15.0] - 2025-10-15

### Added
- Added optional remove parameter to rebuild_read_model to control whether the read model should be removed before rebuilding
- Added CommandNotFoundError to CommandUtils for handling unknown events

### Changed
- Refactored ReadModelRebuilder to delegate event processing to ReadModelUpdater for consistent behavior
- Increased max_retries from 6 to 10 in ReadModelRevisionGuard for better resilience in high-concurrency scenarios

### Fixed
- Fixed ReadModelUpdater to gracefully handle unknown events by catching CommandNotFoundError and updating only the revision

## [0.14.1] - 2025-10-14

### Fixed
- Fixed ReadModelUpdater to gracefully handle RevisionAlreadyAppliedError by catching and logging the error instead of propagating it

## [0.14.0] - 2025-10-11

### Changed
- Increased MAX_RETRIES from 5 to 10 in CommandExecutor for better handling of transient failures
- Added inline recovery attempt after 5 retries to prevent infinite loops from stuck pending states
- Implemented exponential backoff sleep between concurrent update retries
- Reduced recovery threshold from 5 to 2 seconds for faster detection of stuck states
- Increased recovery timeout from 5 to 30 seconds

### Added
- Added attempt_inline_recovery method to ReadModelRecoveryService for inline recovery during command execution

### Fixed
- Fixed infinite retry loops when process crashes leave pending flags set
- Improved handling of RevisionAlreadyAppliedError by clearing lingering pending flags

## [0.13.0] - 2025-10-06

### Added
- Added draft read model support to aggregate authorizers

## [0.12.1] - 2025-10-02

### Fixed
- Fixed locale handling in ReadModelUpdater to avoid mutating command payload

## [0.12.0] - 2025-10-01

### Added
- Added support for disabling read models in aggregates by passing `read_model false` in aggregate class definition

### Changed
- Attribute accessors return nil when read model is disabled
- Command execution uses event stream revision instead of read model revision when read model is disabled

## [0.11.0] - 2025-10-01

### Added
- Added array type to type lookup

### Changed
- Improved guard evaluator implementation with cleaner code structure

### Fixed
- Added support for extra payload in guard errors

## [0.10.3] - 2025-09-26

### Changed
- Improved OpenTelemetry span configuration formatting for better readability
- Enhanced event publisher telemetry with SQL tracking and response recording

## [0.10.2] - 2025-09-26

### Added
- Added OpenTelemetry tracing to command handling pipeline

## [0.10.1] - 2025-09-26

### Fixed
- Patch release with dependency updates

## [0.10.0] - 2025-09-26

### Added
- Added OpenTelemetry instrumentation for command handling
- Added missing YARD documentation for authorize method parameters

### Changed
- Refactored read model recovery service to require aggregate parameter
- Cleaned up RSpec configuration and test file requires

### Fixed
- Fixed RSpec test incompatibility with prepended modules

## [0.9.7] - 2025-09-15

### Added
- Added rake task for loading structure.sql

### Changed
- Switched dummy app to SQL schema format
- Improved command handling implementation
- Refactored command handling specs to use real classes
- Updated remaining specs to use real models
- Cleaned up Gemfiles and database setup

## [0.9.6] - 2025-09-11

### Changed
- Refactored CommandHandling module following SOLID principles
- Updated specs to use real models and improve test structure

### Fixed
- Replaced unique index with PostgreSQL trigger for concurrent update prevention

## [0.9.5] - 2025-09-10

### Fixed
- Fixed command name extraction from draft and edit template events

## [0.9.4] - 2025-09-10

### Fixed
- Fixed stream context reference in pending update error handling
- Fixed configuration spec tests to use correct method signature

### Added
- Added legacy draft compatibility for edit templates

## [0.9.3] - 2025-09-10

### Fixed
- Fixed missing plural read model names in configuration

### Added
- Added documentation for pending update tracking generator

## [0.9.2] - 2025-09-10

### Fixed
- Fixed long index name errors in pending update tracking migration

## [0.9.1] - 2025-09-10

### Fixed
- Fixed generator specs to use temporary directory to avoid conflicts
- Updated generator specs to match actual template output
- Simplified spec cleanup logic to preserve existing migrations
- Fixed generator error handling

## [0.9.0] - 2025-09-10

### Added
- Added pending update tracking to read models for better synchronization
- Added read model recovery service and job for handling out-of-sync read models

### Changed
- Integrated pending update tracking into command handling workflow
- Enhanced read model update mechanism with pending state management

## [0.8.0] - 2025-09-08

### Added
- Added guards option to skip guard evaluation in commands
- Draft mode skips guard evaluation by default

### Changed
- Command processor updated to pass guards option based on draft mode

## [0.7.3] - 2025-09-04

### Fixed
- Fixed regression allowing custom batch id for command processor

## [0.7.2] - 2025-09-04

### Fixed
- Fixed draft mode not being considered when reading aggregate events

## [0.7.1] - 2025-09-04

### Fixed
- Fixed ordering for draft meta tags check in event publisher - legacy key needs precedence

## [0.7.0] - 2025-09-04

### Added
- Added legacy support for edit_template_command metadata
- Added specs for edit_template_command metadata support

## [0.6.0] - 2025-08-29

### Added
- Added `latest_event` and `event_revision` methods to Aggregate
- Added `init_revision_from_stream`method to has_read_model for initializing the read model's revision column with the current event stream revision

## [0.5.0] - 2025-08-22

### Added
- Added `commands` instance method to Aggregate class for accessing available command classes

### Changed
- Improved test isolation and added comprehensive draft handling tests
- Fix: Moved draft metadata handling to execute_command_and_update_state to fix using commands with shorthand sytax on drafts

## [0.4.0] - 2025-08-22

### Added
- Added `changes_read_model_public` option to draftable aggregates
- Added `changes_read_model_public?` method to check template read model visibility status
- Template read models marked as public are now automatically registered for API access via railtie

### Changed
- Enhanced draftable module to allow control over changes read model (template read model) API visibility
- Default behavior maintains backward compatibility with public visibility

## [0.3.0] - 2025-08-21

### Added
- Draft mode support for aggregates

### Changed
- Enhanced command utilities and event publishing
- Improved command processor functionality

## [0.2.2] - 2025-08-21

### Fixed
- Fixed draft aggregate class resolution to include ::Aggregate suffix
- Changed foreign key naming convention from _id to _change_id suffix

## [0.2.1] - 2025-08-21

### Fixed
- Patch release with dependency updates

## [0.2.0] - 2025-08-21

### Added
- Initial minor version release

### Changed
- Version bump from 0.1.x to 0.2.0

### Fixed
- Various minor improvements and bug fixes