# Changelog

## [1.0.0] - 2026-03-21

### Changed
- Initial open-source release
- Synchronized versioning across all gems (yes, yes-core, yes-command-api, yes-read-api)
- Removed all private Yousty gem dependencies
- Standardized dummy app locations to `spec/dummy/` in each gem
- Standardized on PostgreSQL for all test databases
- Consolidated docker-compose configuration
- Inlined RuboCop configuration (removed private remote config dependency)
- Standardized gemspec metadata (MIT license, consistent URIs, Ruby >= 3.2.0, Rails >= 7.1)
- Deduplicated shared test support into `yes-core/lib/yes/core/test_support`
- Resolved all TODO comments in codebase
- Added SimpleCov coverage to yes-core
