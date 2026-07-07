# Target model 0.1.0 — theo.4

Logical patch: `0.1.0_03_theo`
Application version: `0.1.0+16`
Model version: `target-model-0.1.0-theo.4`
Effective date: `2026-07-07`

## Mandatory recalculation

The app performs one mandatory, versioned recalculation on the first startup after this model is installed. The interface blocks navigation, displays progress and tells the user not to close the app. The gate reads the model version stored at the beginning of today’s `targetSourceHash`. A missing day or an older model version forces recalculation; the new version appears only after the profile and all current/future snapshots have been saved successfully.

Every profile save that changes target, activity or macro configuration uses the same atomic flow: show a blocking progress overlay, recompute current/future snapshots, save profile and daily records in one ObjectBox transaction, then invalidate the related providers. Historical snapshots remain unchanged.

Relevant files:

- `lib/features/nutrition/data/services/target_recalculation_service.dart`
- `lib/features/nutrition/presentation/target_recalculation_gate.dart`
- `lib/features/profile/presentation/profile_settings_screen.dart`

## Body-composition integration

When sufficient comparable BIA data exists, the observed body-energy change is blended as:

```text
compositionEnergy = fatMassSlope × 9500 + fatFreeMassSlope × 1020
weightEnergy = weightSlope × 7700
effectiveBodyEnergy = compositionEnergy × confidence
                    + weightEnergy × (1 − confidence)
observedTdee = meanValidIntake − effectiveBodyEnergy
```

Conservative activation rules:

- at least 7 distinct composition days;
- at least 14 days of temporal coverage;
- no interval between measurements greater than 10 days;
- same device throughout the window;
- mathematically coherent weight, fat mass and fat-free mass;
- water variation no greater than 6 percentage points;
- plausible slopes: weight ≤ 0.25 kg/day, fat mass ≤ 0.15 kg/day and fat-free mass ≤ 0.15 kg/day in absolute value;
- confidence at least 0.55.

Confidence combines day count (30%), temporal coverage (25%), maximum gap (20%), water stability (15%) and device identification (10%). These thresholds are conservative engineering heuristics for household BIA, not clinical validation. When any condition fails, the model records the reason and automatically falls back to the weight-only prior of 7700 kcal/kg.

Visceral fat, subcutaneous fat, muscle mass, bone mass and metabolic age are not added separately to energy change because they overlap with fat mass or fat-free mass, or are derived indicators.

Relevant files:

- `lib/features/nutrition/domain/target_model_constants.dart`
- `lib/features/nutrition/domain/target_model_math.dart`
- `lib/features/nutrition/data/services/food_analytics_service.dart`

## Macronutrients

Default mode remains unchanged:

- protein: 1.8 g/kg;
- fat: 25% of energy;
- carbohydrates: residual energy;
- fibre: `max(25 g, 14 g / 1000 kcal)`;
- free sugars: 10% limit and 5% preferred target.

The new personalized mode stores protein, fat and carbohydrates in g/kg. Fibre and free-sugar targets remain automatic. The app calculates calories implied by the entered macro values with the 4/4/9 factors, shows the difference from the active target and suggests a proportional correction. The correction preserves the relative distribution chosen by the user and scales all three g/kg values by:

```text
correctionFactor = targetKcal / macroCalculatedKcal
```

Legacy modes remain readable and are never converted silently.

Relevant files:

- `lib/features/profile/domain/profile_codes.dart`
- `lib/features/profile/domain/profile_nutrition_calculator.dart`
- `lib/features/profile/presentation/profile_settings_screen.dart`

## Calculation details UI

The daily calculation sheet now begins with graphical summary cards for final target, reference TDEE, effective activity and observed reliability. Each section has a distinct icon and border. The body-composition area explicitly reports whether the composition model is active, its confidence, raw composition energy and effective blended energy.

Relevant file:

- `lib/features/nutrition/presentation/food_v01_screens.dart`

## Composition data-selection correction

The composition trend is built directly from every active scale measurement
inside the adaptive reference window. A scale measurement no longer needs a
matching `DailyRecordEntity` on the same date. Measurements are grouped by
`dateKey`, reduced with daily medians and then passed to the quality assessment.

When at least two mathematically valid composition dates exist, the app also
calculates fat-mass, fat-free-mass and weight slopes for diagnostics before
applying the activation gates. A fallback caused by insufficient days or
insufficient temporal coverage can therefore show the raw composition
candidate instead of only `n/d`. The candidate is not used in the final TDEE
until every configured quality rule passes.

The calculation sheet reports valid composition days, temporal coverage,
maximum measurement gap, candidate availability and a readable fallback reason.

## Calculation-warning layout

Calculation alerts and partial-nutrition alerts are no longer rendered on the
Food Plan dashboard. In the daily adaptive-calculation sheet they appear before
the summary metrics. Every alert can be hidden for the current sheet opening.
All calculation sections use foldable expansion tiles; the final-formula section
starts expanded and the remaining sections can be opened independently.

## Parameters still awaiting user validation

Only these two parameter groups remain explicitly pending:

### Sedentary/base factor

Canonical constant:

```text
lib/features/nutrition/domain/target_model_constants.dart
TargetModelConstants.rmrActivityFactor = 1.10
```

Persisted profile default:

```text
lib/features/profile/data/entities/user_profile_entity.dart
rmrActivityFactor = 1.10
```

Assignment during settings save:

```text
lib/features/profile/presentation/profile_settings_screen.dart
profile.rmrActivityFactor = TargetModelConstants.rmrActivityFactor
```

### TDEE guardrails

Canonical constants:

```text
lib/features/nutrition/domain/target_model_constants.dart
TargetModelConstants.minimumReasonableTdee = 1300
TargetModelConstants.maximumReasonableTdee = 4600
```

Persisted profile defaults:

```text
lib/features/profile/data/entities/user_profile_entity.dart
minimumReasonableTdee = 1300
maximumReasonableTdee = 4600
```

Application points:

- `lib/features/profile/domain/profile_nutrition_calculator.dart`
- `lib/features/nutrition/data/services/food_analytics_service.dart`
- helper: `TargetModelMath.applyGuardrail` in `lib/features/nutrition/domain/target_model_math.dart`

Changing the canonical defaults affects newly initialized profiles. Existing stored profiles retain their persisted values unless a migration or explicit settings assignment updates them.

## Remaining scope

After manual validation of the two groups above, the nutritional target model is considered sufficiently defined for this release and work can move to the workout module. Workout sessions continue to expose `estimated_active_calories`; the nutrition module consumes that value without deriving it from exercise internals.
