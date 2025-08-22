# Changelog

All notable changes to this project will be documented in this file.

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