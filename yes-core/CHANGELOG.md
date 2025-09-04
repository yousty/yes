# Changelog

All notable changes to this project will be documented in this file.

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