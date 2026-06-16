# Changelog

All notable changes to this project will be documented in this file.

## [1.3.1] - 2026-06-16

### yes

#### Added
- Umbrella `yes` gem bundling all four sub-gems (`yes-core`, `yes-auth`, `yes-command-api`, `yes-read-api`) so consumers can depend on a single gem.

### yes-auth

#### Added
- Rebuild the principals mirror rows on resource-access `Restored` events, so a restored read/write resource access re-materializes the principal it grants.

### yes-core

#### Fixed
- `Yes::Core::Utils::HashUtils.deep_flatten_hash` now applies the `prefix` to array-valued keys, consistently with scalar and nested-hash keys. Previously an array value was keyed by its bare name (e.g. `deep_flatten_hash({ tags: [...] }, 'span')` produced `"tags"` instead of `"span.tags"`), so callers passing a prefix got a mix of namespaced and un-namespaced keys. Callers that pass no prefix are unaffected.

## [1.3.0] - 2026-05-18

### yes-core

#### Added
- `command_group :name do … end` DSL macro on `Yes::Core::Aggregate` for declaring aggregate-scoped command groups that execute several existing aggregate commands as one atomic, transactionally-published unit. Inside the block: `command :sub_name` lists existing commands by symbol (declaration order = execution order; sub-command guards are bypassed), and `guard(:name) { … }` declares group-level guards using the same DSL as per-command guards. All sub-events publish inside a single `PgEventstore.client.multiple` block at serializable isolation; the first event uses optimistic locking against the read model revision + external-aggregate revision tracking, and subsequent events use `expected_revision: :any`. Read-model updates run after the eventstore commit, in declaration order, so each sub-command's state-updater sees the cumulative state of the previous ones. Per `command_group :foo` the DSL generates `Context::Aggregate::CommandGroups::Foo::Command`, `Context::Aggregate::CommandGroups::Foo::GuardEvaluator`, plus `Aggregate#foo(payload, guards:, metadata:)`, `Aggregate#can_foo?(payload)`, and `Aggregate#foo_error`. Initial scope is single-aggregate groups; the legacy stateless `Yes::Core::Commands::Group` / `GroupHandler` are unchanged and continue to serve cross-aggregate use cases.
- Test DSL extension: `command_group 'name' do … end` block in `Yes::Core::TestSupport::Aggregate::CommandTestDsl` with `success_group`, `invalid_group`, `no_change_group` helpers and three matching shared examples that mirror the per-command DSL.
- `Yes::Core::Commands::GroupPayloadNormalizer` — standalone module extracted from `Yes::Core::Commands::Group#normalized_payloads` that normalizes the three legacy payload shapes (flat / subject-nested / context-nested). `Group` now delegates to it; the new `CommandGroup` reuses it. Existing `Group`/`GroupHandler` behavior is preserved.

#### Fixed
- `Yes::Core::TestSupport::Aggregate::CommandTestDsl` now resolves the draft `expected_event_type` the same way the runtime does, so specs against a `draftable` aggregate that configures `changes_read_model:` no longer fail with `expected "Foo::AggregateDraftEvent" / got "Foo::CustomChangesReadModelEvent"`. The 1.1.0 fix to `CommandUtils#aggregate_name_with_draft_suffix` was not mirrored in the test DSL; this aligns the two and adds focused unit coverage via the new `CommandTestDsl.expected_event_prefix` helper.

## [1.2.0] - 2026-04-30

### yes-core

#### Added
- Auto-injected `:not_removed` guard on `removable` aggregates. Calling `removable` now blocks every non-`:remove` command on the aggregate while the removal attribute (default `removed_at`) is set, so consumers no longer need to hand-write `guard(:not_removed) { removed_at.blank? }` on every mutation. The check is implemented as a runtime pre-check in `Yes::Core::CommandHandling::GuardEvaluator#call`, so it is order-independent (works whether `removable` is declared before or after the other commands) and fires before any registered guard — including the auto-injected `:no_change`. Post-remove mutations consistently raise `GuardEvaluator::InvalidTransition` with the i18n message under `aggregates.<context>.<aggregate>.commands.<command>.guards.not_removed.error` (with the existing generic fallback). The `:remove` command itself is exempt and remains gated only by its existing `:no_change`.
- Aggregate-level opt-out: `removable not_removed_guards: false` disables the auto-block for the whole aggregate.
- Per-command opt-out: both `command` and `parent` accept a new `skip_default_guards: %i[not_removed]` keyword argument that exempts the affected command from the auto-block. The kwarg is stored on `Yes::Core::Aggregate::Dsl::CommandData#skip_default_guards` and respected by the pre-check.
- `Yes::Core::Aggregate.removable_config` reader exposing the `{ attr_name:, not_removed_guards: }` hash recorded by `removable`.

#### Fixed
- `AggregateShortcuts.display` (the `shortcuts` Rails console helper) now writes directly to STDOUT via `puts`. Previously it used `Rails.logger.debug`, which made the helper unusable in production where Rails apps configure structured / JSON loggers (e.g. semantic_logger) — each line came back wrapped in a JSON envelope.

## [1.1.0] - 2026-04-28

### yes-core

#### Added
- `Yes::Core::TestSupport::Aggregate` — aggregate test DSL with command matchers and shared examples for asserting state transitions and emitted events from aggregate commands.
- `Yes::Core::Middlewares.without` — helper that temporarily removes one or more middlewares for the duration of a block, useful in tests and one-off command runs.

#### Fixed
- Draft commands against a `draftable` aggregate that configures `changes_read_model:` now append events to the configured stream (camelized `changes_read_model_name`) instead of falling back to a hard-coded `<Aggregate>Draft` name. Previously this raised `PgEventstore::WrongExpectedRevisionError` for any aggregate whose existing draft history lived on the configured stream. Aggregates that don't pass `changes_read_model:` keep the legacy `<Aggregate>Draft` / `<Aggregate>EditTemplate` behavior.
- Zeitwerk no longer eager-loads `Yes::Core::TestSupport` in non-test contexts, preventing test-helper code paths from being mounted in production.
- `AggregateShortcuts.load!` no longer silently skips aggregates whose subject name has a single capital letter and is 4 chars or shorter (e.g. `Task`, `User`, `Star`). Previously the auto-generated abbreviation collided with the subject's own namespace module and the shortcut was dropped.

#### Changed
- For single-capital subject names, the auto-generated shortcut now uses the **full subject name** instead of the first 4 characters. Examples: `Board → Board` (was `Boar`), `Location → Location` (was `Loca`). Multi-capital names are unchanged (`ContactInfo → CI`).
- Shortcut context modules (e.g. `TF`) are now fresh `Module.new` instances rather than aliases of the real context module, so shortcut constants cannot collide with the aggregates' own namespace modules.

### yes-auth

#### Added
- Migration generators for the auth principal models: `yes:auth:install`, `yes:auth:principals:user`, `yes:auth:principals:role`, `yes:auth:principals:user_role`, `yes:auth:principals:read_resource_access`, `yes:auth:principals:write_resource_access`. Each generates the corresponding migration so consuming apps can scaffold the auth tables without copying SQL by hand.

## [1.0.0] - 2026-03-21

### Added
- Initial release of the Yes framework for building event-sourced Ruby on Rails applications
- Core DSL for defining aggregates, commands, events, projections, and process managers
- Command API engine with built-in authorization and validation
- Read API engine with filterable, sortable, and paginatable query endpoints
- Auth gem with Cerbos-based authorization and pluggable auth adapters
- Encryption middleware for sensitive event data
- ActionCable and MessageBus notifiers for real-time updates
- Subscription management for event handlers
- Comprehensive test support utilities
- Full documentation and contributing guidelines
