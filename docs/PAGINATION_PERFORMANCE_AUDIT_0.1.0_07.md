# Pagination and performance audit — 0.1.0-07

## Scope

This refinement covers the growing interactive archives involved in the reported regressions. The standard interactive page size is 10 records. Export and backup continue to process the full active dataset and are not restricted to the visible page.

| Area | Classification | Query behavior | Images |
|---|---|---|---|
| Local ingredient archive (`+ Alimento`) | `PAGINATED_DATABASE` | ObjectBox filters search/brand and applies count, offset and limit before materialization | Only the 10 visible records are built |
| Meal ingredient drawer | `PAGINATED_DATABASE` | The screen supplies `loadIngredientPage`, page size 10, request-id discard and session page cache | Only the current page is built |
| Recipe ingredient selector | `PAGINATED_DATABASE` | Uses `IngredientRepository.loadIngredientPage`, page size 10 and debounced search | Only the current page is built |
| Ingredient usage (“Quando l’ho mangiato”) | `PAGINATED_DATABASE` + `BACKGROUND_QUERY` | A meal-root ObjectBox query applies date filters, backlink, count, ordering, offset and limit; page mapping runs with `Store.runAsync` | Not applicable |
| Scale archive | `PAGINATED_DATABASE` | Active-only ObjectBox query ordered by date/id, page size 10 | Not applicable |
| Tape archive | `PAGINATED_DATABASE` | Active-only ObjectBox query ordered by date/id, page size 10; entries are loaded only for the visible measurements | Not applicable |
| Combined measurement history | `BOUNDED_MERGE` | Scale and tape are separate entity types. Each query is bounded to the prefix required for the requested page, then the two bounded results are merged deterministically | Not applicable |
| Measurement charts | `QUERY_INTERVAL_OR_BOUNDED_SERIES` | They must not use only the visible page as if it were the complete historical dataset. This patch leaves the hub series bounded and separates them from paged archives | Not applicable |
| Daily meal slots | `FIXED_LIST_NOT_PAGEABLE` | Four fixed slots for one day | Not applicable |
| `.totaltracker` export/import | `FULL_BATCH_OPERATION` | Full active dataset by design; visible-page pagination must never truncate a backup | Not applicable |
| Workout foundation | `OUT_OF_SCOPE` | No workout module UI or schema is introduced by this refinement | Not applicable |

## Residual constraints

- The combined scale+tape history cannot be represented by one ObjectBox query because it spans two entity types. The implementation performs a bounded deterministic merge rather than loading both complete archives.
- Existing global analytics and export operations are not converted to visible-page pagination. They require complete or interval-based data and must run as bounded/background work instead.
- Device validation is still required for image decoding, keyboard insets, small viewports, background/resume and perceived latency.

## Automatic validation requirements

The patch launcher must complete all of the following before committing:

1. `dart format` and format check for every modified Dart file;
2. `git diff --check`;
3. `flutter analyze --no-pub` with no issues;
4. targeted repository, picker, measurement, lifecycle, transfer and cache tests;
5. repeated picker and pagination tests;
6. two complete `flutter test --no-pub` runs;
7. `flutter build apk --debug --no-pub`;
8. explicit inspection of native process exit codes and output markers so failed tests cannot be classified as successful.
