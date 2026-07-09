# Total Tracker transfer coverage audit - refinement 0.1.0-07

Base commit: `75a0a4c277774471843815acea5fddebd6fa7dcd`
Repair base commit: `1838c4ec5628144d39aea6ce5932e616513324fa`

## Acceptance markers

- `APP_VERSION_BASE=0.1.0+19`
- `APP_VERSION_CURRENT=0.1.0+20`
- `TRANSFER_SCHEMA_VERSION=2`
- `TRANSFER_LEGACY_SCHEMA_ACCEPTED=1`
- `TRANSFER_CURRENT_MODEL_COVERAGE=COMPLETE_ACTIVE_PORTABLE_STATE`
- `TRANSFER_PREVIOUS_VERSION_IMPORT=COVERED_BY_CODEC_VERSION_1_COMPAT`
- `TRANSFER_EMPTY_STORE_ROUNDTRIP=COVERED_BY_TRANSFER_TESTS`
- `TRANSFER_SCHEMA_2_REAL_ROUNDTRIP=COVERED_BY_TOTAL_TRACKER_TRANSFER_ROUNDTRIP_TEST`
- `TRANSFER_SCHEMA_1_FIXTURE_IMPORT=COVERED_BY_SCHEMA_1_MINIMAL_FIXTURE`
- `TRANSFER_CORRUPTION_ROLLBACK=COVERED_BY_CODEC_SECURITY_TESTS`
- `TRANSFER_DOUBLE_IMPORT=COVERED_BY_TOTAL_TRACKER_TRANSFER_ROUNDTRIP_TEST`
- `TRANSFER_CONFLICT_POLICY=COVERED_BY_TOTAL_TRACKER_TRANSFER_SERVICE_TEST`

`COMPLETE_ACTIVE_PORTABLE_STATE` means the active, user-portable ObjectBox state
handled by the current transfer service. It excludes runtime caches, derived
rebuildable state, transient queues, diagnostics logs and soft-deleted records
that are intentionally not exported by schema 2.

## Model and DTO inventory

The current service exports and imports sections `profile`, `ingredients`,
`recipes`, `days`, `meals`, `scaleMeasurements`, `tapeMeasurements`, `muscles`,
`exercises`, `routines`, `workoutPlans` and `workoutSessions`.

| Area | ObjectBox entities / data family | Export | Import | Compatibility | Real test coverage |
|---|---|---:|---:|---|---|
| Profile | `UserProfileEntity` settings and portable preferences | yes | yes | schema 2 DTO, conflict choices | repository suite and transfer service tests |
| Ingredients | `IngredientEntity` nutrients, source, image reference, audit fields | active only | yes | schema 1 fixture plus schema 2 | schema 2 two-store round-trip, schema 1 fixture |
| Recipes | `RecipeEntity`, ingredients, steps and media references | active only | yes | schema 2 parent DTO | transfer current model contract and full suite |
| Food days | `DailyRecordEntity` target snapshots and portable daily fields | active only | yes | schema 2 day DTO | transfer current model contract and full suite |
| Meals | `MealEntity`, `MealItemEntity` and nutrition snapshots | active only | yes | relationships rebuilt by UUID/date | transfer current model contract and full suite |
| Scale measurements | `ScaleMeasurementEntity` composition, device and audit fields | active only | yes | schema 2 scale DTO | transfer current model contract and measurement delete tests |
| Tape measurements | `TapeMeasurementEntity`, `TapeMeasurementEntryEntity` values and positions | active only | yes | children rebuilt from parent DTO | transfer current model contract and measurement delete tests |
| Workout | `MuscleEntity`, `ExerciseEntity`, `ExerciseMuscleLinkEntity`, routines, plans, sessions and sets | active only | yes | schema 2 workout DTOs | workout foundation and transfer contract tests |
| Media sidecars | portable recipe/ingredient image references and sidecar import path | referenced | imported when present | codec hash validation | archive security and sidecar tests |
| Runtime | queues, timers, subscriptions, diagnostics, locks and caches | no | no | intentionally transient | n/a |
| Privacy | tokens, custom paths, diagnostics logs and secrets | no | no | intentionally excluded | archive security and privacy tests |

## Executable validation

- Schema 2 round-trip: `test/features/transfer/total_tracker_transfer_roundtrip_test.dart`
  creates a source Store, exports a real `.totaltracker`, imports it into an
  empty destination Store and compares canonical portable ingredient state.
- Schema 1 compatibility: `test/fixtures/transfer/schema_1_minimal.totaltracker`
  imports through the legacy checksum path without exceptions.
- Corrupt archive rollback: truncated/corrupt archives are rejected before
  writing and leave the destination Store unchanged.
- Transaction rollback: a forced failure inside `Store.runInTransaction` proves
  partial ObjectBox writes are rolled back and pre-existing state is preserved.
- Idempotence: importing the same schema 2 archive twice creates no duplicate
  active ingredient records.

## Limits

The round-trip test intentionally focuses on a representative portable seed and
does not claim Android process-death, filesystem permission, media gallery or
device-profile performance validation. Those remain part of device validation
and full-suite regression, not of the transfer codec contract itself.
