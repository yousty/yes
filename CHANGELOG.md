## [Unreleased]

# 0.4.1 - 2026-01-28
* Bump yes-command-api dependency to 2.4.2
* Bump yes-core dependency to 0.23.3
* Bump yes-read-api dependency to 1.4.4

# 0.4.0 - 2026-01-28
* Bump yes-command-api dependency to 2.4.0
* Bump yes-core dependency to 0.23.0
* Bump yes-read-api dependency to 1.4.0

## [0.3.3] - 2025-08-21

### Changed
- Refactored draftable module to simplify draft aggregate updates
- Removed `draft_foreign_key` configuration method and related logic
- Improved foreign key resolution with fallback to draft aggregate class method
- Enhanced private method encapsulation and naming conventions

## [0.3.2] - 2025-08-12

### Changed
- **BREAKING**: Refactored `draftable` method signature to consolidate configuration
  - Removed separate `changes_read_model` method
  - Added `changes_read_model` as parameter to `draftable` method
  - Nested `context` and `aggregate` parameters under `draft_aggregate` hash
  - Example: `draftable(draft_aggregate: { context: '...', aggregate: '...' }, changes_read_model: '...')`
- Renamed internal `draft_read_model` references to `changes_read_model` for consistency

### Added
- Comprehensive documentation for the `draftable` feature in README

## [0.3.1] - 2025-08-11

### Changed
- Made `draft?` method public on draftable aggregates to allow checking if an aggregate instance was initialized as a draft
- Renamed `HasDraftable` module to `Draftable` for better naming consistency

### Fixed
- Fixed test support file `test_aggregates.rb` that had incorrect DSL usage

## [0.3.0] - 2025-08-11

- Add draftable functionality to aggregates
- Update documentation and gitignore

## [0.2.0]

- Add read API test setup
- Refactor command API specs

## [0.1.0] - 2024-11-11

- Initial release
