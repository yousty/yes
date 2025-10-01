# Changelog

All notable changes to this project will be documented in this file.

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