# Local Database

Total Tracker uses ObjectBox as the local database.

The database is opened during app bootstrap through `ObjectBoxDatabase`, then
the resulting `Store` is exposed to repositories through Riverpod providers.
Repositories must receive the shared Store and must not open their own Store.

Production data is stored under the application documents directory in the
`total_tracker_objectbox` subfolder. Tests must pass an explicit temporary
directory to `ObjectBoxDatabase.open()`.

## Generated Model Files

ObjectBox code generation is performed with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

The generated `objectbox-model.json` and `lib/objectbox.g.dart` files are part
of the source-controlled schema and must be versioned. The model file contains
ObjectBox entity and property UIDs used for stable migrations; do not delete it
or edit generated UIDs manually. Entity and property renames require care so the
generator can preserve migration identity.

## Current Scope

Implemented in schema version 1:

- user profile;
- ingredients;
- muscle catalog;
- exercises;
- exercise-muscle links.

Not implemented in this phase:

- fridge or food inventory;
- meals;
- recipes;
- food plans;
- body measurements;
- routines;
- workout sessions;
- Health Connect;
- online synchronization;
- backend.
