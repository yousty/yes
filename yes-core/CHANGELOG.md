# Changelog

## [Unreleased]

### Fixed
- `AggregateShortcuts.load!` no longer silently skips aggregates whose subject name has a single capital letter and is 4 chars or shorter (e.g. `Task`, `User`, `Star`). Previously the auto-generated abbreviation collided with the subject's own namespace module and the shortcut was dropped.

### Changed
- For single-capital subject names, the auto-generated shortcut now uses the **full subject name** instead of the first 4 characters. Examples: `Board → Board` (was `Boar`), `Location → Location` (was `Loca`). Multi-capital names are unchanged (`ContactInfo → CI`).
- Shortcut context modules (e.g. `TF`) are now fresh `Module.new` instances rather than aliases of the real context module, so shortcut constants cannot collide with the aggregates' own namespace modules.

## [1.0.0] - 2026-03-21

- Initial open-source release (see root CHANGELOG.md for details)
