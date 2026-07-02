# Total Tracker Portable Archive v1

Extension: `.totaltracker`

The file is a ZIP archive containing:

- `manifest.json`: format, version, app version, timestamp, selected areas and counts;
- `data.json`: portable entities using UUIDs and natural keys, without ObjectBox numeric IDs;
- `checksums.json`: FNV-1a checksums for corruption detection.

The import process is read-only until the final confirmation. It validates the
archive, detects categories, compares UUIDs and natural keys, lets the user
select entities page by page and finally applies all selected changes inside a
single ObjectBox write transaction.

Device-local settings such as the export directory are not exported.

Conflict matching order:

1. UUID;
2. category-specific natural key;
3. normalized name as fallback where appropriate.

Supported categories:

- profile fields;
- ingredients;
- recipes with ingredients and steps;
- daily records;
- meals with meal items;
- scale measurements;
- tape measurements with entries;
- muscles;
- exercises with muscle links;
- routines with exercises and set templates;
- workout plans with days and exercises;
- workout sessions with exercises and sets.
