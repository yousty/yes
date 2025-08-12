## [Unreleased]

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
