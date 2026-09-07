# Changelog

All notable changes to this project will be documented in this file.

## [2.4.0] - 2026-09-07

### yes-core

#### Added
- `Authorization::CerbosGrpcRetryPolicy` and the `cerbos_grpc_channel_args` configuration option.
  The Cerbos client now carries a gRPC retry policy that retries `UNAVAILABLE` calls (up to 4
  attempts, exponential backoff from 100ms) so a PDP pod that is killed or restarting mid-check
  no longer surfaces as `Cerbos::Error::Unavailable`.

#### Changed
- `Authorization::CerbosClientProvider` keeps one `Cerbos::Client` (one gRPC channel) per
  process instead of building a new client, and opening new connections, on every check. The
  client is rebuilt after a fork; `CerbosClientProvider.reset!` drops it explicitly (tests).

## [2.3.0] - 2026-09-03

### yes-core

#### Added
- `CommandHandling::RevisionConflictBackoff` and `RevisionConflictWaiting`: an
  exponential, jittered backoff (10 ms → 1 s per attempt, 2 s in total) applied
  between revision-conflict retries while the read model still lags the stream.

#### Changed
- `CommandExecutor` and `CommandGroupExecutor` wait for the read model to catch up
  before retrying a `PgEventstore::WrongExpectedRevisionError` instead of retrying
  immediately; conflicts the same process caused still retry at once.
- The `ConcurrentUpdateError` retries take their delay from
  `RevisionConflictBackoff.schedule`; timing unchanged.

#### Fixed
- `EventPublisher#verify_external_revisions!` and `Stateless::Handler#revision_error!`
  raise `WrongExpectedRevisionError` with pg_eventstore's field order: `revision` is the
  store's value, `expected_revision` the caller's. Both were inverted.


## [2.2.0] - 2026-09-01

### yes-core

#### Added
- `Authorization::LookupCache` — scoped memoization for the read-only lookups an
  authorization pass repeats.

  Caching is opt-in per scope: outside `LookupCache.with_scope` its `fetch` just yields,
  so nothing changes for callers that do not open a scope. The store lives in
  `ActiveSupport::IsolatedExecutionState`, so it is per thread/fiber, and `with_scope`
  clears it on the way out — including when the block raises — so nothing leaks into the
  next request. Nested scopes reuse the outermost cache.

#### Changed
- `Authorization::CommandCerbosAuthorizer` resolves the principal data and the
  authorized resource through `LookupCache`.

  Authorizing a batch of commands used to repeat both lookups once per command. The
  principal data is derived purely from the request's auth data, and the commands of a
  batch commonly act on the same resource, so both were re-read from the database for
  every command — for an N-command batch, N times the queries for N identical results.
  In production traces the two lookups accounted for the large majority of the authorize
  span, dwarfing the Cerbos call itself.

  This is safe because a batch is authorized in full before any of its commands is
  executed, so no write can invalidate either lookup while the pass is running. Cached
  values are shared between the commands of a pass and must be treated as read-only;
  the per-command Cerbos payload is still built, and checked, per command.

- The `Cerbos Authorize Command` span now tracks SQL, so the time it spends in-process
  can be attributed to queries rather than guessed at.

### yes-command-api

#### Changed
- `Commands::BatchAuthorizer` authorizes a batch inside a single
  `Yes::Core::Authorization::LookupCache` scope, which is what lets the authorizers of
  one batch share their principal and resource lookups.

## [2.1.1] - 2026-08-22

### yes-core

- `Types::UUID` now accepts any RFC 9562 UUID version (1-8), not only v4.

  pg_eventstore 3.0.0 moved event-id generation off the database's `gen_random_uuid()`
  (always v4) to `SecureRandom.uuid_v7`. Those ids reach the gem as `causation_id` /
  `correlation_id`, and a v4-only pattern makes `TransactionDetails.new` raise
  `Dry::Struct::Error` — which fails the event handler and kills the subscription once
  its restarts are exhausted.

  Still a real constraint: version must be 1-8 and the variant nibble 8/9/a/b, so
  arbitrary hex in UUID shape is rejected as before.

  **Required for anything running pg_eventstore 3.x.**

- Register a `failed_subscription_notifier` so a dead subscription reports to Sentry.

  `config.failed_subscription_notifier` is pg_eventstore's only death signal — it is
  called once, when a subscription exhausts its restarts and stays dead. Without it that
  death is silent: per-failure errors are only recorded on the subscription row and are
  never raised, so a subscription can stop processing indefinitely with no alert.

  Registered only when the host application has loaded Sentry.

  Shipped alongside the UUID fix deliberately: that fix addresses a bug which *kills*
  subscriptions, and this is what tells you when one has died.

## [2.1.0] - 2026-07-31

### yes-core

#### Added
- `Middlewares::WriteEncryptor` — encrypts on `#serialize` exactly like `Middlewares::Encryptor`
  (it subclasses it), but its `#deserialize` is a no-op.
- `Middlewares.register_encryptor(key_repository, config:)` — registers `:encryptor` and
  `:write_encryptor` together. Host applications should call this instead of assigning
  `config.middlewares[:encryptor]` by hand; registering the decrypting encryptor on its own doubles
  the encryptor round trips of every encrypted append.
- `Middlewares.for_write` — the middleware keys to pass to `#append_to_stream`: every configured
  middleware, with `:encryptor` swapped for `:write_encryptor`. Derived from the live config rather
  than hard-coded, because `PgEventstore::Client` resolves a passed list with
  `config.middlewares.slice(*list)`, which silently drops unregistered names — a literal list could
  therefore resolve to one with no encryptor at all and write plaintext at rest. Falls back to the
  full list when `:write_encryptor` is missing, and the railtie warns about that at boot.
- `Middlewares::ENCRYPTOR` / `Middlewares::WRITE_ENCRYPTOR` config-key constants, and
  `DataEncryptor::CIPHERTEXT_KEY` for the `es_encrypted` data key.

#### Changed
- Every write site now appends with `middlewares: Middlewares.for_write`, so an append no longer
  decrypts the event it returns: `CommandHandling::EventPublisher`,
  `CommandHandling::CommandGroupExecutor`, `Commands::Stateless::Handler` and
  `TestSupport::EventHelpers#append_event`. This covers both `PgEventstore#multiple` paths, whose
  sub-events publish through those same call sites.

  pg_eventstore 3.0 runs every registered middleware's `#deserialize` on the events returned by
  `#append_to_stream`, not only on reads. Nothing in yes-core reads `data` off that returned event —
  `otl_record_response` records only type, revision, stream and positions, and `ReadModelUpdater`
  always receives the command payload on the write path — so each encrypted append was paying an
  uncached key lookup plus a decrypt against the encryptor service for a payload it discarded. Those
  calls also ran inside the SERIALIZABLE transaction opened by `#multiple`, widening the window for
  `PG::TRSerializationFailure` and its retries.

  ⚠️ Consumers that relied on the appended event coming back decrypted must read the event instead.

#### Fixed
- `Middlewares::Encryptor#serialize` is now idempotent: it returns the event untouched when the data
  is already encrypted. Required because the default middleware list holds two serialize-capable
  encryptors once `:write_encryptor` is registered, so an append that omits `middlewares:` would
  otherwise encrypt twice — the second pass encrypting the first pass's sentinels and overwriting the
  real ciphertext irrecoverably. It also makes re-appending an event that was read at rest
  (`middlewares: Middlewares.without(:encryptor)`) safe, which it was not before.

## [2.0.0] - 2026-07-28

Major bump because `yes-core` now requires `pg_eventstore` v3, whose schema is
incompatible with v1. Released as 2.0.0 rather than 1.5.0 deliberately: consumers
constrain these gems at `~> 1.3`, which 1.5.0 would satisfy, so a minor bump could
be pulled in by an unrelated `bundle update` and put v3 code against a v1 store.
2.0.0 makes that impossible.

⚠️ **Do not adopt until your event store has been migrated to v3.** Migrating is a
one-way, downtime-requiring operation — see the `pg_eventstore` upgrade notes.

### yes-core

#### Changed
- **Breaking change**: `pg_eventstore` dependency `~> 1.0` → `~> 3.0`.
- **Breaking change**: OpenTelemetry span attribute `event.link_id` is now
  `event.link_global_position`, in `Commands::Stateless::Handler` and
  `CommandHandling::EventPublisher`. `pg_eventstore` v3 drops `events.link_id`
  (migration 13) in favour of the bigint `link_global_position`, so `Event#link_id`
  raises `NoMethodError`.
  **Update any dashboards or trace queries keyed on `event.link_id`.**

### yes-auth

#### Changed
- **Breaking change**: `yes-core` dependency `~> 1.0` → `~> 2.0`, required to stay
  resolvable alongside yes-core 2.0.0.

## [1.4.0] - 2026-06-24

### yes-command-api

#### Added
- Dispatch aggregate-DSL command groups over the HTTP command API. The deserializer now resolves the `<Context>::<Subject>::CommandGroups::<Name>::Command` class-name convention (generated by the `command_group` macro) in addition to the legacy top-level group, V2, and V1 conventions. The controller expands a `Yes::Core::Commands::CommandGroup` into its sub-commands for batch authorization and validation, while still passing the wrapped group to the command bus so the Processor dispatches it as one atomic unit.

### yes-core

#### Added
- `Yes::Core::Commands::CommandGroup#to_h` now returns the flat input payload merged with reserved keys, so a group round-trips cleanly through `Class.new(to_h)` (used by the command bus' `add_metadata` and by the ActiveJob serializer). Reserved keys (`origin`, `batch_id`, `command_id`, `metadata`, `transaction`) now propagate to the aggregate group method through that round-trip.
- `Yes::Core::ActiveJobSerializers::CommandGroupSerializer` now serializes aggregate-DSL `CommandGroup`s as well as the legacy stateless `Group`, so groups survive the async command queue.
- `Yes::Core::Configuration#command_group_guard_evaluator_class` resolves a command group's guard evaluator from the `:command_group_guard_evaluator` registry, and `Processor#guard_evaluator_exists?` uses it for `CommandGroup` instances. A group registers its guard evaluator under that dedicated registry type, so without this the existence check raised `UnregisteredCommand` when a group was dispatched.

#### Changed
- `Yes::Core::Commands::Processor#run_command` no longer special-cases `CommandGroup` payloads; the flat `#to_h` makes a single code path correct for both single commands and groups (drops the `reinstantiate_with_reserved_keys` helper).

## [1.3.1] - 2026-06-16

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
