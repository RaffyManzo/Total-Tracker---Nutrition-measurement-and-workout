# Project Setup

## Environment Detected

- Operating system: Microsoft Windows 10.0.22631, x64
- Flutter: not available in PATH (`flutter` command not recognized)
- Dart: not available in PATH (`dart` command not recognized)
- Java: 17.0.12 LTS
- Git: 2.38.1.windows.1
- GitHub CLI: not available in PATH (`gh` command not recognized)

## Android SDK Status

- Android SDK detected under the default local Android SDK location.
- `ANDROID_HOME`: not set
- `ANDROID_SDK_ROOT`: not set
- `adb`: not available in PATH, but available inside the Android SDK.
- Connected devices: none detected through the SDK `adb` binary.
- Emulator AVDs: none listed.
- Installed platforms detected: android-28, android-31, android-33, android-34, android-35, android-35-ext14
- Installed build tools detected: 30.0.2, 33.0.0, 34.0.0, 35.0.0
- Android license files detected: android-sdk-arm-dbt-license, android-sdk-license

## Project Creation

Expected Flutter command:

```bash
flutter create --org com.raffymanzo --project-name total_tracker --platforms android,ios .
```

The command could not be executed because Flutter is not installed or not available in PATH in the current environment.

The initial project scaffold was created manually in the repository root so the work that does not require the Flutter SDK could still be completed.

## Identifiers

- Flutter technical name: `total_tracker`
- Display name: `Total Tracker`
- Android package: `com.raffymanzo.totaltracker`
- iOS bundle identifier: `com.raffymanzo.totaltracker`

## Dependencies Declared

Runtime dependencies declared in `pubspec.yaml`:

- `flutter_riverpod`
- `go_router`
- `drift`
- `sqlite3_flutter_libs`
- `path`
- `path_provider`
- `uuid`
- `freezed_annotation`
- `json_annotation`

Development dependencies declared in `pubspec.yaml`:

- `build_runner`
- `drift_dev`
- `freezed`
- `json_serializable`
- `flutter_lints`

The package versions are intentionally left for the Dart package solver because `flutter pub add` and `flutter pub get` could not be executed without Flutter.

## Structure Created

```text
lib/
  app/
    app.dart
    router/
      app_router.dart
    theme/
      app_theme.dart
  core/
    constants/
    database/
      README.md
    errors/
    services/
    utils/
  features/
    README.md
  main.dart
assets/
  data/
  icons/
  images/
docs/
  PROJECT_SETUP.md
test/
  app_test.dart
```

## Verification Commands

| Command | Result |
| --- | --- |
| `dart format .` | Blocked: `dart` command not recognized |
| `flutter pub get` | Blocked: `flutter` command not recognized |
| `flutter analyze` | Blocked: `flutter` command not recognized |
| `flutter test` | Blocked: `flutter` command not recognized |
| `flutter build apk --debug` | Blocked: `flutter` command not recognized |
| `flutter doctor -v` | Blocked: `flutter` command not recognized |

## Residual Issues

- Flutter stable SDK must be installed or added to PATH.
- Dart is not available separately in PATH.
- GitHub CLI is not installed or not available in PATH, so `gh auth status` cannot be checked.
- Android SDK exists, but Android SDK environment variables are not configured.
- No Android device or emulator is currently available.
- The Flutter-generated native project files could not be verified by a build in this environment.

## Reproducing The Setup

After installing Flutter stable and adding it to PATH:

```bash
flutter --version
dart --version
flutter doctor -v
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

If GitHub CLI is installed:

```bash
gh auth status
```

No backend, cloud synchronization, Drift tables, DAOs, migrations, nutritional models, workout models, or Obsidian data imports are part of this setup phase.
