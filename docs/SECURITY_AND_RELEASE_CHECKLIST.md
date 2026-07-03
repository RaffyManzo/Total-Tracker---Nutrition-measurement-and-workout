# Total Tracker — Security and release checklist

Baseline hardened by this patch: `a6255b2e333fa3de74a9080e012a56a8d7fc3f58`.

## Included in this patch

- Removed the startup routine that could delete meals, daily records and ingredients when a local marker was absent.
- Upgraded accidental-corruption detection from FNV-1a to SHA-256 while retaining read compatibility for version 1 archives. SHA-256 here is not a signature and does not prevent deliberate modification by an attacker who can recompute it.
- Added strict ZIP entry allow-listing, duplicate rejection, path-traversal rejection, checksum verification, JSON depth/node limits and compressed/expanded size limits.
- Made export writes transactional through a temporary file and rename.
- Rejected missing, empty or oversized import files before loading them into memory.
- Disabled Android Auto Backup and device-transfer extraction for application data.
- Disabled clear-text network traffic at Android application level.
- Consolidated OpenNutrition background-job state into one JSON preference with legacy migration.
- Increased stale thresholds to avoid treating normal WorkManager delays as failures.
- Removed mock and design-preview routes from the release router.
- Added bounded PNG/JPEG/WebP header parsing with maximum dimensions and pixel count before local ingredient images are persisted.
- Added CI for formatting, analysis, gateway dependency installation, gateway security checks and Android debug compilation.
- Added focused transfer-archive and image-dimension security tests. They are supplied but are not run by the application script, in accordance with the current validation workflow.

## Required before a public release

- [ ] Design and implement an encrypted `.totaltracker` archive version with a password UI and authenticated encryption. Version 2 adds integrity and anti-DoS controls, but exported content remains readable by anyone who obtains the file.
- [ ] Define password recovery and migration behavior before enabling archive encryption. Do not invent a silent device-bound key because it would make cross-device restore unreliable.
- [ ] Deploy the OpenNutrition gateway behind HTTPS with a real domain, reverse proxy/WAF, request-size limits and distributed rate limiting.
- [ ] Generate an offline Ed25519 signing key, mount it as a secret, publish only the public key in the app and document rotation/revocation.
- [ ] Generate and validate the indexed read-only OpenNutrition database used by the production container.
- [ ] Decide whether local database encryption is required for the threat model. Android backup exclusion does not protect data on an already-unlocked or rooted device.
- [ ] Bring `flutter analyze` to zero warnings and infos.
- [ ] Run the focused tests added by this patch before release, even though they are not executed by the patch script.
- [ ] Review all dependency advisories and lockfile changes after `flutter pub get`.

## Device regression matrix

Use recognizable test data and confirm it survives each scenario:

1. Normal close/reopen and process eviction from recent apps.
2. Device restart.
3. Installation of a newer APK over the existing version.
4. OpenNutrition download/import with the app backgrounded and then terminated.
5. Network loss during download, verification and import.
6. Cancellation at each stage, including repeated cancellation.
7. Battery saver, restricted background execution and delayed WorkManager scheduling.
8. Storage almost full and write permission/storage-provider failure.
9. Notifications denied, later granted and disabled per category.
10. Camera permission denied and permanently denied.
11. Duplicate barcode and duplicate imported records.
12. Ingredient modification/deletion while referenced by meals or recipes.
13. Export followed by import into an empty installation.
14. Corrupted, oversized, duplicate-entry and path-traversal archives.
15. Date, clock and time-zone changes around reminder deadlines.

## Scope

Workout implementation is deliberately excluded from this hardening pass and must not block validation of the remaining application.
