# Project Setup

## Environment Detected

- Operating system: Microsoft Windows 10.0.22631, x64
- Flutter: not available in PATH during the current Codex session
- Dart: not available in PATH during the current Codex session
- Git: available, but this checkout requires per-command `safe.directory`
  because Git reports dubious ownership

The repository must be built with Flutter stable and Dart 3. The current Codex
session could not execute Flutter or Dart commands because neither executable is
available in PATH.

## Identifiers

- Flutter technical name: `total_tracker`
- Display name: `Total Tracker`
- Android package: `com.raffymanzo.totaltracker`
- iOS bundle identifier: `com.raffymanzo.totaltracker`

## Dependencies Declared

Runtime dependencies declared in `pubspec.yaml`:

- `flutter_riverpod`
- `go_router`
- `objectbox`
- `objectbox_flutter_libs`
- `path`
- `path_provider`
- `uuid`
- `freezed_annotation`
- `json_annotation`

Development dependencies declared in `pubspec.yaml`:

- `build_runner`
- `objectbox_generator`
- `freezed`
- `json_serializable`
- `flutter_lints`

ObjectBox dependencies should be resolved by the package solver with:

```bash
flutter pub get
```

## ObjectBox Generation

After dependency resolution, generate ObjectBox artifacts with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Version the generated `objectbox-model.json` and `lib/objectbox.g.dart` files.
Do not add generated runtime database files to Git.

## Structure

```text
lib/
  app/
  core/
    database/
    identifiers/
    time/
  features/
    nutrition/
    profile/
    workout/
assets/
  data/
  icons/
  images/
docs/
  DATABASE_SCHEMA_V1.md
  PROJECT_SETUP.md
test/
```

## Verification Commands

Run these after Flutter stable is available:

```bash
dart format .
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
flutter test
flutter clean
flutter pub get
flutter build apk --debug
```

If Android `cmdline-tools` or licenses are missing, keep analyze and tests as
the source of truth for the data layer and report the APK failure as an Android
toolchain issue.

## Residual Environment Issues In This Session

- `where.exe flutter` did not find Flutter.
- `where.exe dart` did not find Dart.
- `flutter --version`, `dart --version`, and `flutter doctor -v` were blocked
  because commands were not recognized.
- Git global configuration was not modified; commands requiring Git use
  `git -c safe.directory=C:/Users/raffa/develop/total_tracker ...`.

No backend, cloud synchronization, meals, recipes, body measurements, routines,
sessions, Health Connect, or fridge/inventory features are part of this phase.
