# OpenNutrition static-index pipeline

This directory contains the reproducible build and validation pipeline for
the OpenNutrition index consumed by Total Tracker.

The pipeline:

1. downloads the fixed official dataset archive;
2. verifies its pinned SHA-256 digest;
3. safely extracts only the required allowlisted files;
4. parses and normalizes records into a minimal intermediate index;
5. emits the production candidate with three-character name/alias routing;
6. verifies every shard and executes the semantic benchmark;
7. uploads a GitHub Actions artifact;
8. deploys to Cloudflare Pages only when explicitly requested from `main`.

Open Food Facts remains the primary source in the application. This index is
secondary and an individual result must never be imported without showing a
user-visible summary.

## Reproducibility and supply-chain controls

- Dart is fixed to `3.12.2`.
- Direct Dart dependencies are exact versions.
- `pubspec.lock` is versioned and CI uses `dart pub get --enforce-lockfile`.
- GitHub Actions are pinned to full release commit SHAs.
- The workflow dataset version is not user-editable independently from its
  URL and checksum.
- Dart commands execute from this package directory so package resolution is
  deterministic.
- Python helpers are syntax-checked before the dataset is downloaded.

## Known semantic floor

Dataset `2025.1` currently passes 48/50 strict top-1 queries and 49/50 top-5
queries. Generic `pasta` has no sufficiently generic candidate in the current
source index. The client must be able to return no reliable OpenNutrition
match instead of silently promoting a composed dish.

## Local verification

From this directory:

```text
dart pub get --enforce-lockfile
python -m py_compile safe_extract.py validate_gate.py
dart format --output=none --set-exit-if-changed .
dart analyze .
```

The complete dataset build is intentionally executed by the manual GitHub
Actions workflow.

## Licensing

The emitted database is a derived OpenNutrition database and must remain
publicly downloadable under ODbL 1.0 with OpenNutrition attribution.
