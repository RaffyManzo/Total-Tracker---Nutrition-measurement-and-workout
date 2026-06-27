# Total Tracker

Nutrition, measurement and workout

Total Tracker - Nutrition, measurement and workout is a Flutter mobile application intended to progressively manage nutrition, daily calories, macronutrients, meal plans, body measurements, workouts, training plans, sessions, daily activity, steps, and active calorie expenditure.

Functional requirements come from an existing Obsidian system and will be imported gradually. This initial phase only prepares the mobile project structure and base architecture.

## Project Status

Initial Flutter project scaffold. No definitive product features, nutritional models, workout models, calorie formulas, database schema, backend, or cloud synchronization are implemented yet.

## Technology Stack

- Framework: Flutter
- Language: Dart 3 with null safety
- UI: Material 3
- State management: Riverpod
- Navigation: GoRouter
- Future local database: SQLite through Drift
- Immutable models: Freezed
- Serialization: json_serializable
- Identifiers: UUID

## Prerequisites

- Flutter stable SDK
- Dart 3
- Android SDK and Android toolchain
- Java 17 or compatible JDK
- Git

GitHub CLI is optional for authentication checks and repository workflows.

## Installation

```bash
flutter pub get
```

## Run

```bash
flutter run
```

## Analysis

```bash
flutter analyze
```

## Test

```bash
flutter test
```

## Android Build

```bash
flutter build apk --debug
```

## Directory Structure

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

## Local Database

The first version will be local-first and will use SQLite through Drift. The schema will be defined only after the Obsidian files are analyzed. No hypothetical tables are part of this setup.

## Future Development

Future work will progressively import and translate the existing Obsidian rules and data into app features. A backend or synchronization system may be evaluated later, but neither is implemented at this stage.

## Official Repository

[RaffyManzo/Total-Tracker---Nutrition-measurement-and-workout](https://github.com/RaffyManzo/Total-Tracker---Nutrition-measurement-and-workout)
