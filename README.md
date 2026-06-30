# Total Tracker

Nutrition, measurement and workout

Total Tracker - Nutrition, measurement and workout is a Flutter mobile
application intended to progressively manage nutrition, daily calories,
macronutrients, meal plans, body measurements, workouts, training plans,
sessions, daily activity, steps, and active calorie expenditure.

Functional requirements come from an existing Obsidian system and will be
imported gradually. The current phase establishes the local ObjectBox data
foundation and the first domain primitives.

## Project Status

Initial Flutter project scaffold with the first bottom-up data layer:

- local ObjectBox database configuration;
- default user profile;
- ingredients;
- muscle catalog;
- exercises;
- exercise-muscle associations;
- foundational repositories;
- idempotent muscle catalog seeding;
- data-layer tests.

The fridge/inventory concept is intentionally not part of the application and
is not represented in the schema.

## Technology Stack

- Framework: Flutter
- Language: Dart 3 with null safety
- UI: Material 3
- State management: Riverpod
- Navigation: GoRouter
- Local database: ObjectBox
- Identifiers: UUID

Freezed and json_serializable remain available only because they are already
declared for future app layers; ObjectBox entities in this phase are plain
mutable entity classes.

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

## Code Generation

ObjectBox generated files are created with:

```bash
dart run build_runner build --delete-conflicting-outputs
```

`objectbox-model.json` and `lib/objectbox.g.dart` must be versioned once
generated. Do not delete or regenerate model UIDs arbitrarily.

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
  core/
    database/
    identifiers/
    time/
  features/
    nutrition/
    profile/
    workout/
  main.dart
assets/
  data/
  icons/
  images/
docs/
  DATABASE_SCHEMA_V1.md
  PROJECT_SETUP.md
test/
```

## Local Database

The application is local-first and uses ObjectBox. Production data is stored in
a dedicated application documents subdirectory named
`total_tracker_objectbox`. Tests open independent temporary directories and
must never use the real app database.

See [docs/DATABASE_SCHEMA_V1.md](docs/DATABASE_SCHEMA_V1.md) for the first
schema documentation.

## Future Development

Future work will progressively import and translate the existing Obsidian rules
and data into app features. Meals, recipes, body measurements, routines,
sessions, Health Connect, online synchronization, and backend services are not
implemented in this phase.

## Official Repository

[RaffyManzo/Total-Tracker---Nutrition-measurement-and-workout](https://github.com/RaffyManzo/Total-Tracker---Nutrition-measurement-and-workout)
